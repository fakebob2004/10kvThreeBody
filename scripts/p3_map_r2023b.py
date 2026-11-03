"""Map exported instance metadata to same native R2023b composite-port components.

Usage: python3 scripts/p3_map_r2023b.py <export-directory>
Reads the native R2023b Stage2 template for component class/variant identifiers;
leaves line endpoints, sensor reference convention, and breaker behavior intact.
"""
from pathlib import Path
from zipfile import ZipFile
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
types = {"ee.connectors.grounded_neutral": "ee.connectors.grounded_neutral.abc",
         "ee.sensors.vi_sensor_3ph": "ee.sensors.vi_sensor.abc",
         "ee.switches.circuit_breaker.abc": "ee.switches.circuit_breaker.ps.abc"}
meta = ("SourceFile", "ComponentPath", "ComponentVariants", "ComponentVariantNames", "ClassName")

def params(b):
    return {p.get("Name"): p for p in b.findall("InstanceData/P")}

def system(k):
    return k.startswith("simulink/systems/system_") and k.endswith(".xml")

def adapt(src_dir):
    native = {}
    with ZipFile(root/"build/r2023b/BESS_PV_WIND_STAGE2_R2_API.slx") as z:
        for k in filter(system, z.namelist()):
            for b in ET.fromstring(z.read(k)).findall("Block"):
                p = params(b)
                if "SourceFile" in p and p["SourceFile"].text in types.values():
                    native[p["SourceFile"].text] = {n:p[n].text for n in meta}
    assert len(native) == 3
    for m in ("PV_WIND_BESS_ISLAND_R1","PV_WIND_BESS_SM_FIXED_R1"):
        if (src_dir/(m+".slx")).resolve() == (root/"models/r2023b"/(m+".slx")).resolve():
            raise ValueError("Export directory must differ from the destination.")
        with ZipFile(src_dir/(m+".slx")) as z, ZipFile(root/"models/r2023b"/(m+".slx"),"w") as out:
            for info in z.infolist():
                data = z.read(info); changed = False
                if system(info.filename):
                    doc = ET.fromstring(data)
                    for b in doc.findall("Block"):
                        p=params(b)
                        if "SourceFile" not in p: continue
                        source=p["SourceFile"].text
                        if source in types:
                            for n,value in native[types[source]].items(): p[n].text=value
                            changed=True
                        if b.get("Name")=="PV Array" and source=="ee.sources.solar_cell":
                            assert p["prm"].text=="ee.enum.sources.solar_cell_prm.datasheet"
                            p["prm"].text="1"; changed=True
                        if b.get("Name")=="Precharge Disconnect Switch":
                            assert p["diode_param"].text=="ee.enum.semiconductors.protectionDiode.external"
                            p["diode_param"].text="ee.enum.converters.protectiondiode.none";changed=True
                    if changed: data=ET.tostring(doc,encoding="utf-8",xml_declaration=True)
                out.writestr(info,data)

if __name__=="__main__": adapt(Path(sys.argv[1]))
