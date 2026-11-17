# -*- coding: utf-8 -*-
"""Visor de resultados del laboratorio de triaje de incidentes de pagos.

Solo lee resultados/prueba-*.json y resultado-pruebas.txt: no recalcula ni decide nada.
Requiere solo la biblioteca estándar de Python (tkinter).

Uso:
    python visor_resultados.py            abre la ventana
    python visor_resultados.py --prueba   carga los datos, arma la ventana y la cierra (prueba automática)
"""
import json
import sys
from pathlib import Path
import tkinter as tk
from tkinter import ttk

CARPETA = Path(__file__).resolve().parent

ACCIONES = {
    "escalar": ("ESCALAR", "#b42318", "#fee4e2"),
    "continuar_monitoreo": ("MONITOREAR", "#067647", "#dcfae6"),
    None: ("SIN RECOMENDACIÓN", "#b54708", "#fef0c7"),
}


def cargar_pruebas():
    pruebas = []
    for ruta in sorted((CARPETA / "resultados").glob("prueba-*.json")):
        with open(ruta, encoding="utf-8-sig") as f:  # utf-8-sig: los archivos tienen BOM
            pruebas.append(json.load(f))
    return pruebas


def cargar_verificacion():
    ruta = CARPETA / "resultado-pruebas.txt"
    if not ruta.exists():
        return "Sin verificación: ejecutá .\\paso6-verificar.ps1", "#b54708"
    lineas = ruta.read_text(encoding="utf-8-sig").splitlines()
    ok = sum(1 for l in lineas if l.strip().startswith("OK"))
    falla = sum(1 for l in lineas if l.strip().startswith("FALLA"))
    fecha = lineas[0].replace("Prueba final - ", "") if lineas else ""
    if falla:
        return f"Verificación: {falla} FALLAS, {ok} OK   ({fecha})", "#b42318"
    return f"Verificación: {ok} de {ok} chequeos OK   ({fecha})", "#067647"


TODOS = "(Todos)"


def clave_orden(valor):
    """Ordena como número si el valor empieza con un número ("1", "2 de 2"); si no, como texto."""
    texto = str(valor)
    try:
        return (0, float(texto.split()[0]), texto.lower())
    except (ValueError, IndexError):
        return (1, 0.0, texto.lower())


def ref_texto(r):
    return f"{r['documento']} {r['version']} §{r['seccion']}"


class Visor(tk.Tk):
    def __init__(self, pruebas):
        super().__init__()
        self.pruebas = pruebas
        self.title("Triaje de incidentes de pagos - Resultados")
        self.geometry("1000x640")
        self.minsize(820, 520)
        self.configure(bg="#f8f9fb")

        estilo = ttk.Style(self)
        estilo.theme_use("clam")
        estilo.configure("Treeview", rowheight=30, font=("Segoe UI", 10))
        estilo.configure("Treeview.Heading", font=("Segoe UI", 10, "bold"))

        # Encabezado
        cab = tk.Frame(self, bg="#f8f9fb")
        cab.pack(fill="x", padx=16, pady=(14, 6))
        tk.Label(cab, text="Resultados de la prueba final", font=("Segoe UI", 16, "bold"),
                 bg="#f8f9fb", fg="#101828").pack(anchor="w")
        texto, color = cargar_verificacion()
        tk.Label(cab, text=texto, font=("Segoe UI", 10, "bold"), bg="#f8f9fb", fg=color).pack(anchor="w")

        # Filas: valores visibles de cada prueba (iid = índice en self.pruebas)
        self.columnas = ("prueba", "caso", "accion", "cita", "busquedas", "estado")
        anchos = {"prueba": 60, "caso": 230, "accion": 170, "cita": 160, "busquedas": 90, "estado": 230}
        self.titulos = {"prueba": "#", "caso": "Caso", "accion": "Acción", "cita": "Cita",
                        "busquedas": "Búsquedas", "estado": "Revisión humana"}
        self.filas = []
        for i, p in enumerate(pruebas):
            etiqueta = ACCIONES.get(p.get("accion"), ACCIONES[None])[0]
            cita = ", ".join(ref_texto(r) for r in p.get("referencias") or []) or "—"
            b = p["busquedasDocumentales"]
            valores = (str(p["prueba"]), f"{p['incidente']}  {p['fechaEvaluacion']} {p['horaEvaluacion']}",
                       etiqueta, cita, f"{b['usadas']} de {b['maximo']}",
                       f"{p['revisionHumana']['estado'].upper()}  ({p['etapa']})")
            self.filas.append((str(i), str(p.get("accion")), valores))
        self.orden = (None, False)  # (columna, descendente)

        # Filtros por columna
        barra_filtros = tk.Frame(self, bg="#f8f9fb")
        barra_filtros.pack(fill="x", padx=16, pady=(8, 0))
        self.filtros = {}
        for j, c in enumerate(self.columnas):
            tk.Label(barra_filtros, text=self.titulos[c], font=("Segoe UI", 9, "bold"),
                     bg="#f8f9fb", fg="#475467").grid(row=0, column=j, sticky="w", padx=(0, 8))
            opciones = [TODOS] + sorted({f[2][j] for f in self.filas}, key=clave_orden)
            var = tk.StringVar(value=TODOS)
            combo = ttk.Combobox(barra_filtros, textvariable=var, values=opciones, state="readonly",
                                 width=max(6, anchos[c] // 9))
            combo.grid(row=1, column=j, sticky="w", padx=(0, 8))
            combo.bind("<<ComboboxSelected>>", lambda _e: self.refrescar())
            self.filtros[c] = var
        n = len(self.columnas)
        self.lbl_conteo = tk.Label(barra_filtros, text="", font=("Segoe UI", 9), bg="#f8f9fb", fg="#475467")
        self.lbl_conteo.grid(row=0, column=n, sticky="w")
        ttk.Button(barra_filtros, text="Limpiar filtros", command=self.limpiar_filtros).grid(row=1, column=n, sticky="w")

        # Tabla de pruebas (clic en el encabezado = ordenar)
        self.tabla = ttk.Treeview(self, columns=self.columnas, show="headings", height=len(pruebas), selectmode="browse")
        for c in self.columnas:
            self.tabla.heading(c, text=self.titulos[c], command=lambda c=c: self.ordenar(c))
            self.tabla.column(c, width=anchos[c], anchor="w")
        for clave, (_, fg, bg) in ACCIONES.items():
            self.tabla.tag_configure(str(clave), background=bg, foreground=fg)
        self.tabla.pack(fill="x", padx=16, pady=6)
        self.tabla.bind("<<TreeviewSelect>>", self.mostrar_detalle)

        # Detalle
        marco = tk.Frame(self, bg="#ffffff", highlightbackground="#d0d5dd", highlightthickness=1)
        marco.pack(fill="both", expand=True, padx=16, pady=(6, 16))
        self.detalle = tk.Text(marco, wrap="word", font=("Segoe UI", 10), bd=0, padx=14, pady=10,
                               bg="#ffffff", fg="#101828")
        barra = ttk.Scrollbar(marco, command=self.detalle.yview)
        self.detalle.configure(yscrollcommand=barra.set)
        barra.pack(side="right", fill="y")
        self.detalle.pack(fill="both", expand=True)
        self.detalle.tag_configure("titulo", font=("Segoe UI", 13, "bold"), spacing3=6)
        self.detalle.tag_configure("seccion", font=("Segoe UI", 10, "bold"), foreground="#475467", spacing1=8)
        self.detalle.tag_configure("mono", font=("Consolas", 9), foreground="#344054")
        for clave, (_, fg, bg) in ACCIONES.items():
            self.detalle.tag_configure("acc_" + str(clave), font=("Segoe UI", 11, "bold"),
                                       foreground=fg, background=bg)

        self.refrescar()

    # --- Filtros y ordenamiento ---
    def refrescar(self):
        """Vuelve a llenar la tabla aplicando los filtros y el orden actuales."""
        seleccion = self.tabla.selection()
        self.tabla.delete(*self.tabla.get_children())

        visibles = [f for f in self.filas
                    if all(self.filtros[c].get() in (TODOS, f[2][j]) for j, c in enumerate(self.columnas))]
        col, desc = self.orden
        if col:
            j = self.columnas.index(col)
            visibles.sort(key=lambda f: clave_orden(f[2][j]), reverse=desc)
        for iid, tag, valores in visibles:
            self.tabla.insert("", "end", iid=iid, tags=(tag,), values=valores)

        for c in self.columnas:
            flecha = (" ▼" if desc else " ▲") if c == col else ""
            filtrada = " ⏷" if self.filtros[c].get() != TODOS else ""
            self.tabla.heading(c, text=self.titulos[c] + flecha + filtrada)
        self.lbl_conteo.config(text=f"Mostrando {len(visibles)} de {len(self.filas)}")

        quedan = [s for s in seleccion if self.tabla.exists(s)]
        if quedan:
            self.tabla.selection_set(quedan)
        elif visibles:
            self.tabla.selection_set(visibles[0][0])
        else:
            self.detalle.configure(state="normal")
            self.detalle.delete("1.0", "end")
            self.escribir("Ninguna prueba coincide con los filtros elegidos.", "seccion")
            self.detalle.configure(state="disabled")
        self.mostrar_detalle()

    def ordenar(self, columna):
        col, desc = self.orden
        self.orden = (columna, not desc) if col == columna else (columna, False)
        self.refrescar()

    def limpiar_filtros(self):
        for var in self.filtros.values():
            var.set(TODOS)
        self.refrescar()

    def escribir(self, texto, *tags):
        self.detalle.insert("end", texto, tags)

    def mostrar_detalle(self, _evento=None):
        sel = self.tabla.selection()
        if not sel:
            return
        p = self.pruebas[int(sel[0])]
        ev = p["evidencia"]
        d = self.detalle
        d.configure(state="normal")
        d.delete("1.0", "end")

        self.escribir(f"Prueba {p['prueba']}: {p['incidente']} - {p['fechaEvaluacion']} {p['horaEvaluacion']}\n", "titulo")
        etiqueta = ACCIONES.get(p.get("accion"), ACCIONES[None])[0]
        self.escribir(f"  {etiqueta}  ", "acc_" + str(p.get("accion")))
        self.escribir("\n")

        self.escribir("\nEvidencia de la bitácora  [Regla programada]\n", "seccion")
        self.escribir(f"Reportes: {ev['reportes']}   ·   Entidades: {', '.join(ev['entidades']) or '—'}"
                      f"   ·   Primer reporte: {ev['primerReporte']}   ·   "
                      f"Minutos transcurridos: {ev['minutosDesdePrimerReporte']}\n")

        b = p["busquedasDocumentales"]
        self.escribir(f"\nBúsquedas documentales  [Decisión del agente]  ({b['usadas']} de {b['maximo']})\n", "seccion")
        for s in b["detalle"]:
            self.escribir(f"{s['numero']}. \"{s['consulta']}\"  en {s['indice']}\n")
            recuperado = s.get("recuperado") or []
            if not recuperado:
                self.escribir("     → sin resultados\n", "mono")
            for r in recuperado:
                self.escribir(f"     → {ref_texto(r)}  ({r['motivo']})\n", "mono")

        self.escribir("\nRecomendación  [Decisión del agente]\n", "seccion")
        self.escribir((p.get("recomendacion") or "Ninguna: evidencia insuficiente.") + "\n")
        if p.get("destinatario"):
            self.escribir(f"Destinatario: {p['destinatario']}\n")
        refs = p.get("referencias") or []
        self.escribir("Cita: " + (", ".join(ref_texto(r) for r in refs) if refs else "—") + "\n")

        if p.get("pendientes"):
            self.escribir("\nPendiente para la revisión humana\n", "seccion")
            for x in p["pendientes"]:
                self.escribir(f"•  {x}\n")

        self.escribir("\nRevisión humana  [Regla programada]\n", "seccion")
        self.escribir(f"Estado: {p['revisionHumana']['estado'].upper()}   ·   Etapa: {p['etapa']}\n")
        self.escribir(f"Fundamento: {p['revisionHumana']['fundamento']}\n")
        self.escribir("Decisión humana: " + ("pendiente (la toma una persona)" if p.get("decisionHumana") is None
                                             else json.dumps(p["decisionHumana"], ensure_ascii=False)) + "\n")
        d.configure(state="disabled")


def main():
    pruebas = cargar_pruebas()
    if not pruebas:
        print("No hay resultados en la carpeta 'resultados'. Ejecutá primero las pruebas del paso 6.")
        sys.exit(1)
    app = Visor(pruebas)
    if "--prueba" in sys.argv:
        app.update()
        for i in range(len(pruebas)):  # recorre cada prueba para comprobar que el detalle se arma sin errores
            app.tabla.selection_set(str(i))
            app.mostrar_detalle()
        filas = len(app.tabla.get_children())

        # Filtro: solo MONITOREAR
        app.filtros["accion"].set("MONITOREAR"); app.refrescar()
        filtradas = [app.tabla.set(i, "prueba") for i in app.tabla.get_children()]
        # Filtro combinado: MONITOREAR + cita 2025 -> solo la prueba 3
        app.filtros["cita"].set("PROC-PAG 2025 §4.1"); app.refrescar()
        combinadas = [app.tabla.set(i, "prueba") for i in app.tabla.get_children()]
        # Filtro sin coincidencias: ESCALAR + cita 2025
        app.filtros["accion"].set("ESCALAR"); app.refrescar()
        vacias = len(app.tabla.get_children())
        app.limpiar_filtros()
        # Orden: dos clics en "#" -> descendente
        app.ordenar("prueba"); app.ordenar("prueba")
        desc = [app.tabla.set(i, "prueba") for i in app.tabla.get_children()]

        chequeos = [
            ("4 pruebas cargadas", filas == 4),
            ("Filtro Acción=MONITOREAR -> pruebas 2 y 3", sorted(filtradas) == ["2", "3"]),
            ("Filtro combinado MONITOREAR + 2025 -> prueba 3", combinadas == ["3"]),
            ("Filtro sin coincidencias -> 0 filas", vacias == 0),
            ("Limpiar filtros -> 4 filas", len(app.tabla.get_children()) == 4),
            ("Orden descendente por # -> 4,3,2,1", desc == ["4", "3", "2", "1"]),
        ]
        for nombre, ok in chequeos:
            print(("OK    " if ok else "FALLA ") + nombre)
        print(cargar_verificacion()[0])
        app.destroy()
        if not all(ok for _, ok in chequeos):
            sys.exit(1)
        return
    app.mainloop()


if __name__ == "__main__":
    main()
