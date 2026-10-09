"""Exporta el ER real y la propuesta 2FN para drawDB, dbdiagram y draw.io.

Solo genera documentación; no conecta ni modifica la base de datos.
Uso: python scripts/er_diagram/export_web.py
"""
from __future__ import annotations

import copy
import html
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET

import layout
import model_2nf

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "docs" / "diagramacion_bd"
COLORS = dict(zip(model_2nf.MODULES, ["#D6A100", "#82902D", "#3A7D3A", "#E97532", "#656B99", "#B45535"]))


def table_name(table):
    return f"auth.users" if table.get("external") else table["name"]


def endpoints(relation):
    return (relation.get("from_columns", ["id"]),
            relation.get("to_columns", [relation["fk"].split(" (")[0]]))


def positions(model):
    # Native drawDB rows are 36px high, with a 50px header and a color strip.
    # Change this process's layout constants, leaving the Miro implementation intact.
    layout.TABLE_WIDTH = 460
    layout.ROW_HEIGHT = 36
    layout.HEADER_HEIGHT = 66
    layout.COLUMN_GAP = 250
    layout.ROW_GAP = 100
    result = layout.plan(model, restarts=1)
    shapes = result["shapes"]
    min_y = min(s["y"] - s["height"] / 2 for s in shapes)
    return {s["table"]["name"]: dict(x=s["x"] + 80,
        y=s["y"] - s["height"] / 2 - min_y + 250,
        width=460, height=s["height"]) for s in shapes}


def dbml(model):
    lines = ["// Documentación del esquema; no es una migración ejecutable.",
        "// Las relaciones polimórficas son lógicas y se documentan en notas.",
        "Project nikara {", "  database_type: 'PostgreSQL'",
        "  Note: 'Tablas y nombres de columna verificados contra la API y el inventario Supabase; ver docs/diagramacion_bd/README.md para limitaciones de la consulta y una FK no resuelta.'", "}", ""]
    tables = {t["name"]: t for t in model["tables"]}
    quote = lambda s: "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ") + "'"
    for t in tables.values():
        note = t["source"]
        if t.get("derived"):
            note += "; PROPUESTA 1FN/2FN: no existe todavía en el esquema físico"
        if t['name'] == 'routes':
            note += '; cloned_from_route_id figura en una migración; PostgREST no pudo resolver esta relación y requiere confirmar pg_catalog'
        if t['name'] == 'reviews_backup':
            note = 'Inventario real proporcionado y verificado por API; respaldo auxiliar, sin PK; solo se incluye en el esquema físico'
        for r in model["relations"]:
            if r["to"] == t["name"] and r.get("polymorphic"):
                note += f"; RELACIÓN LÓGICA: {r['fk']} -> {table_name(tables[r['from']])}.id (sin FK SQL)"
        lines.append(f"Table {table_name(t)} [headercolor: {COLORS[t['module']]}, note: {quote(note)}] {{")
        for c in t["columns"]:
            flags = []
            if c.get("pk") and len(t["pk"]) == 1:
                flags.append("pk")
            if c.get("not_null") or c.get("pk"):
                flags.append("not null")
            if c.get("unique"):
                flags.append("unique")
            kind = c["type"]
            if " " in kind:
                kind = json.dumps(kind)
            lines.append(f"  {json.dumps(c['name'])} {kind}" + (f" [{', '.join(flags)}]" if flags else ""))
        keys = t.get("unique_keys", [])
        if len(t["pk"]) > 1 or keys:
            lines.append("  indexes {")
            if len(t["pk"]) > 1:
                lines.append(f"    ({', '.join(t['pk'])}) [pk]")
            for key in keys:
                lines.append(f"    ({', '.join(key)}) [unique]")
            lines.append("  }")
        lines.extend(["}", ""])
    for i, r in enumerate(model["relations"]):
        if r.get("polymorphic"):
            continue
        parents, children = endpoints(r)
        field = lambda cols: cols[0] if len(cols) == 1 else f"({', '.join(cols)})"
        op = "-" if r["kind"] == "1:1" else "<"
        lines.append(f"Ref fk_{i}: {table_name(tables[r['from']])}.{field(parents)} {op} {table_name(tables[r['to']])}.{field(children)}")
        if r.get("not_valid"):
            lines.append("// FK anterior declarada NOT VALID: registros históricos pueden no cumplirla.")
    return "\n".join(lines) + "\n"


def drawdb(model, pos, title):
    tables = []
    lookup = {}
    for i, t in enumerate(model["tables"]):
        lookup[t["name"]] = (i, {c["name"]: j for j, c in enumerate(t["columns"])})
        fields = []
        for j, c in enumerate(t["columns"]):
            comments = []
            if c.get("references"):
                comments.append("FK: " + c["references"])
            if t['name'] == 'routes' and c['name'] == 'cloned_from_route_id':
                comments.append('FK en migración; relación no resuelta por PostgREST')
            for r in model["relations"]:
                if r["to"] == t["name"] and c["name"] in endpoints(r)[1]:
                    if r.get("composite"):
                        comments.append("FK COMPUESTA (una sola restricción): " + r["fk"])
                    if r.get("polymorphic"):
                        comments.append("LÓGICA según discriminador; no es FK SQL: " + r["from"])
            fields.append(dict(id=j, name=c["name"], type=c["type"].upper(),
                default="", check="", primary=bool(c.get("pk")),
                unique=bool(c.get("unique") or (c.get("pk") and len(t["pk"]) == 1)),
                notNull=bool(c.get("not_null") or c.get("pk")), increment=False,
                comment="; ".join(comments)))
        source_note = ("Inventario Supabase confirmado; respaldo histórico sin PK" if t['name'] == 'reviews_backup' else t["source"])
        tables.append(dict(id=i, name=table_name(t), **{k: pos[t['name']][k] for k in ['x','y','width']},
            fields=fields, comment=source_note + ("; PROPUESTA 2FN" if t.get("derived") else ""),
            indices=[], uniqueConstraints=[dict(name=f"uq_{i}_{k}",fields=v) for k,v in enumerate(t.get('unique_keys',[]))],
            color=COLORS[t["module"]], locked=False, hidden=False, collapsed=False))
    relationships = []
    for r in model["relations"]:
        parents, children = endpoints(r)
        a, af = lookup[r["to"]]
        b, bf = lookup[r["from"]]
        for k, (parent, child) in enumerate(zip(parents, children)):
            # drawDB paints the relationship's `name` at the midpoint of the
            # connector. Keep it readable: use the actual FK field(s), not an
            # internal identifier that looks like a generated constraint name.
            if r.get("polymorphic"):
                name = f"Lógica · {r['fk']}"
            elif r.get("composite"):
                name = f"FK compuesta · {k+1}/{len(parents)}"
            else:
                name = f"{r['kind']} · {child}"
            relationships.append(dict(id=len(relationships), startTableId=a, startFieldId=af[child],
                endTableId=b, endFieldId=bf[parent],
                name=name,
                cardinality="one_to_one" if r["kind"] == "1:1" else "many_to_one",
                updateConstraint="No action", deleteConstraint="No action"))
    return dict(title=title, database="postgresql", tables=tables, relationships=relationships,
        subjectAreas=[], types=[], enums=[
            dict(name='user_role', values=['turista','emprendedor','admin','auditor']),
            dict(name='booking_status', values=['pendiente','confirmada','completada','cancelada']),
        ], views=[], notes=[dict(id=0, x=80,y=10,width=900,height=180,
            title=title, color="#FCF7AC", locked=False,
            content="PK = clave primaria; FK = clave foránea. PROPUESTA 2FN = tabla nueva. "
            "LOGICA__ = referencia polimórfica, no FK SQL. COMPUESTA_1_DE_2 y COMPUESTA_2_DE_2 "
            "representan juntas UNA FK compuesta. Para el modelo formal completo usar el .drawio; "
            "para claves SQL usar DBML, que omite relaciones lógicas. Este JSON es visual: "
            "no exportar sus conectores como migración. Colores por área: "
            "Identidad (dorado), Negocios (oliva), ECO (verde), Rutas (naranja), "
            "Social (azul) y Avisos (terracota). Esquema revisado con inventario "
            "Markdown de Supabase y consultas REST de cero filas; revisar el informe para sus límites.")])


def drawio_page(file, model, title, page_id, pos):
    diagram = ET.SubElement(file,"diagram",id=page_id,name=title)
    graph = ET.SubElement(diagram,"mxGraphModel",dx="1400",dy="900",grid="1",gridSize="10",guides="1",tooltips="1",connect="1",arrows="1",fold="1",page="0",pageScale="1",math="0",shadow="0")
    root = ET.SubElement(graph,"root")
    ET.SubElement(root,"mxCell",id="0")
    ET.SubElement(root,"mxCell",id="1",parent="0")
    note = ET.SubElement(root,"mxCell",id="legend",value=title+"<br>Colores: Identidad dorado · Negocios oliva · ECO verde · Rutas naranja · Social azul · Avisos terracota.<br>PK: clave primaria · FK: clave foránea · UQ: única<br>Tabla con [2FN]: propuesta; backup sin PK: solo esquema físico<br>Línea naranja punteada: referencia lógica según discriminador; sin FK SQL<br>Línea roja punteada: la API no resolvió la FK recursiva declarada en migración<br>FK compuesta: una línea une el conjunto de columnas.<br>auth.users: entidad externa de Supabase; solo se muestra su clave.<br>Origen: inventario del usuario y API REST con LIMIT 0, migraciones y documentación; detalles en el informe.",style="text;html=1;align=left;verticalAlign=top;whiteSpace=wrap;fontSize=16;",vertex="1",parent="1")
    ET.SubElement(note,"mxGeometry",x="80",y="0",width="1200",height="200",attrib={"as":"geometry"})
    for t in model["tables"]:
        composite_columns = {c for fk in t.get("foreign_keys",[]) for c in fk['columns']}
        rows=[]
        for c in t['columns']:
            markers=[]
            if c.get('pk'): markers.append('PK')
            if c.get('references') or c['name'] in composite_columns: markers.append('FK')
            if c.get('unique'): markers.append('UQ')
            rows.append(f"<tr><td style='width:65px;color:#526174'>{','.join(markers)}</td><td>{html.escape(c['name'])}</td><td style='color:#526174'>{html.escape(c['type'])}</td></tr>")
        label=f"<b>{html.escape(table_name(t))}{' [2FN]' if t.get('derived') else ''}</b><hr><table style='font-family:monospace;font-size:12px;width:100%;line-height:32px'>{''.join(rows)}</table>"
        cell=ET.SubElement(root,'mxCell',id='t_'+t['name'],value=label,style=f"rounded=1;whiteSpace=wrap;html=1;align=left;verticalAlign=top;spacing=12;fillColor=#FFFFFF;strokeColor={COLORS[t['module']]};strokeWidth=2;fontColor=#1E293B;",vertex='1',parent='1')
        ET.SubElement(cell,'mxGeometry',attrib={**{k:str(v) for k,v in pos[t['name']].items()},'as':'geometry'})
    for i,r in enumerate(model['relations']):
        style="edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;endArrow=ERmany;startArrow=ERone;startFill=0;endFill=0;fontSize=11;labelBackgroundColor=#FFFFFF;strokeColor=#94A3B8;"
        if r['kind']=='1:1': style=style.replace('endArrow=ERmany','endArrow=ERone')
        if r.get('optional'): style=style.replace('startArrow=ERone','startArrow=ERzeroToOne')
        if r.get('polymorphic'): style += 'dashed=1;strokeColor=#E97532;'
        if r.get('api_unverified'): style += 'dashed=1;strokeColor=#B42318;strokeWidth=3;'
        else:
            if r['kind']=='1:1': style=style.replace('endArrow=ERone','endArrow=ERzeroToOne')
            else: style=style.replace('endArrow=ERmany','endArrow=ERzeroToMany')
        parent_cols,child_cols=endpoints(r)
        label=f"{r['kind']} · {', '.join(child_cols)}"
        if r.get('composite'): label=f"{r['kind']} · ({', '.join(child_cols)}) → ({', '.join(parent_cols)})"
        if r.get('polymorphic'): label=f"LÓGICA · {r['fk']}"
        if r.get('api_unverified'): label=f"FK de migración; PostgREST no la resolvió · {r['fk']}"
        if r.get('not_valid'): label += ' · NOT VALID'
        edge=ET.SubElement(root,'mxCell',id=f'r_{i}',value=label,style=style,edge='1',parent='1',source='t_'+r['from'],target='t_'+r['to'])
        ET.SubElement(edge,'mxGeometry',relative='1',attrib={'as':'geometry'})


def write_files(model, basename, title, modules=False):
    pos=positions(model)
    (OUT / f"{basename}.dbml").write_text(dbml(model),encoding='utf8')
    (OUT / f"{basename}.drawdb.json").write_text(json.dumps(drawdb(model,pos,title),indent=2,ensure_ascii=False)+'\n',encoding='utf8')
    file=ET.Element('mxfile',host='app.diagrams.net',agent='Nikára ER exporter',version='24.7.17')
    drawio_page(file,model,title,'general',pos)
    if modules:
        for i,module in enumerate(model['modules']):
            selected={t['name'] for t in model['tables'] if t['module']==module}
            relations=[r for r in model['relations'] if r['to'] in selected or r['from'] in selected]
            names=selected | {r[k] for r in relations for k in ['from','to']}
            partial={**model,'tables':[t for t in model['tables'] if t['name'] in names],'relations':relations}
            drawio_page(file,partial,module,f'module_{i}',positions(partial))
    ET.indent(file)
    ET.ElementTree(file).write(OUT / f'{basename}.drawio',encoding='utf-8',xml_declaration=True)
    print(f'{basename}: {len(model["tables"])} entidades, {len(model["relations"])} relaciones')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    normalized=model_2nf.build()
    snapshot_path=OUT/'supabase_api_verificacion.json'
    if snapshot_path.is_file():
        snapshot=json.loads(snapshot_path.read_text(encoding='utf8'))
        if any(item['from'] == 'routes' and item['to'] == 'routes'
               and not item['relationship_resolves']
               for item in snapshot['foreign_key_relationships']):
            for relation in normalized['relations']:
                if relation['from'] == 'routes' and relation['to'] == 'routes':
                    relation['api_unverified']=True
    physical=json.loads((HERE/'schema_physical.json').read_text(encoding='utf8'))
    actual=copy.deepcopy(normalized)
    assigned={t['name']:t['module'] for t in normalized['tables']}
    actual['tables']=physical['tables']+[copy.deepcopy(next(t for t in normalized['tables'] if t.get('external')))]
    names={t['name'] for t in actual['tables']}
    for t in actual['tables']:
        t['module']=assigned.get(t['name'], 'Interacción social')
        t['pk']=[c['name'] for c in t['columns'] if c.get('pk')]
    actual['relations']=[r for r in normalized['relations'] if r['from'] in names and r['to'] in names]
    write_files(actual,'nikara_esquema_actual','Níkara — esquema físico')
    write_files(normalized,'nikara_modelo_2fn','Níkara — modelo ER hasta 2FN',modules=True)


if __name__=='__main__':
    main()
