from pathlib import Path
import re
import uuid

path = Path(__file__).resolve().parents[1] / "Afterna.xcodeproj" / "project.pbxproj"
text = path.read_text(encoding="utf-8")
files = [
    ("Notifications/LocalNotificationService.swift", "Notifications"),
    ("LiveActivity/RecordingActivityAttributes.swift", "LiveActivity"),
    ("LiveActivity/RecordingLiveActivityController.swift", "LiveActivity"),
    ("Features/Brief/MeetingBriefSheet.swift", "Brief"),
    ("Features/People/PeopleView.swift", "People"),
]
to_add = [(rel, group) for rel, group in files if Path(rel).name not in text]
print("to_add", to_add)
if not to_add:
    print("nothing to add")
    raise SystemExit(0)


def rid() -> str:
    return uuid.uuid4().hex[:24].upper()


ask_build = "0A51A15EE7C24B6A9F1D2C30 /* AskAISheet.swift in Sources */"
ask_ref = "0A51A15EE7C24B6A9F1D2C31 /* AskAISheet.swift */"
if ask_build not in text:
    raise SystemExit("AskAISheet build entry missing")

build_lines = []
ref_lines = []
source_lines = []
group_entries: dict[str, list[tuple[str, str, str]]] = {}
for rel, group in to_add:
    name = Path(rel).name
    bref = rid()
    fref = rid()
    build_lines.append(
        f"\t\t{bref} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};\n"
    )
    ref_lines.append(
        f"\t\t{fref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
    )
    source_lines.append(f"\t\t\t\t{bref} /* {name} in Sources */,\n")
    group_entries.setdefault(group, []).append((fref, name, rel))

text = text.replace(
    ask_build + " = {isa = PBXBuildFile; fileRef = 0A51A15EE7C24B6A9F1D2C31 /* AskAISheet.swift */; };",
    ask_build
    + " = {isa = PBXBuildFile; fileRef = 0A51A15EE7C24B6A9F1D2C31 /* AskAISheet.swift */; };\n"
    + "".join(build_lines).rstrip("\n"),
    1,
)
text = text.replace(
    ask_ref
    + " = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AskAISheet.swift; sourceTree = \"<group>\"; };",
    ask_ref
    + " = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AskAISheet.swift; sourceTree = \"<group>\"; };\n"
    + "".join(ref_lines).rstrip("\n"),
    1,
)
src_marker = "\t\t\t\t0A51A15EE7C24B6A9F1D2C30 /* AskAISheet.swift in Sources */,\n"
if src_marker not in text:
    raise SystemExit("sources marker missing")
text = text.replace(src_marker, src_marker + "".join(source_lines), 1)

feat = re.search(
    r"(/\* Features \*/ = \{\s*isa = PBXGroup;\s*children = \(\n)([\s\S]*?)(\n\t\t\t\);\s*path = Features;)",
    text,
)
if feat:
    inserts = []
    for group, items in group_entries.items():
        if group not in ("Brief", "People"):
            continue
        gid = rid()
        child_lines = "".join(f"\t\t\t\t{fref} /* {name} */,\n" for fref, name, _ in items)
        group_block = (
            f"\t\t{gid} /* {group} */ = {{\n"
            f"\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = (\n"
            f"{child_lines}"
            f"\t\t\t);\n"
            f"\t\t\tpath = {group};\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};\n"
        )
        text = text.replace("/* Begin PBXGroup section */\n", "/* Begin PBXGroup section */\n" + group_block, 1)
        inserts.append(f"\t\t\t\t{gid} /* {group} */,\n")
    if inserts:
        feat = re.search(
            r"(/\* Features \*/ = \{\s*isa = PBXGroup;\s*children = \(\n)([\s\S]*?)(\n\t\t\t\);\s*path = Features;)",
            text,
        )
        assert feat
        text = text[: feat.start(2)] + feat.group(2) + "".join(inserts) + text[feat.end(2) :]

afterna = re.search(
    r"(/\* Afterna \*/ = \{\s*isa = PBXGroup;\s*children = \(\n)([\s\S]*?)(\n\t\t\t\);\s*path = Afterna;)",
    text,
)
if afterna:
    inserts = []
    for group, items in group_entries.items():
        if group not in ("Notifications", "LiveActivity"):
            continue
        gid = rid()
        child_lines = "".join(f"\t\t\t\t{fref} /* {name} */,\n" for fref, name, _ in items)
        group_block = (
            f"\t\t{gid} /* {group} */ = {{\n"
            f"\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = (\n"
            f"{child_lines}"
            f"\t\t\t);\n"
            f"\t\t\tpath = {group};\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};\n"
        )
        text = text.replace("/* Begin PBXGroup section */\n", "/* Begin PBXGroup section */\n" + group_block, 1)
        inserts.append(f"\t\t\t\t{gid} /* {group} */,\n")
    if inserts:
        afterna = re.search(
            r"(/\* Afterna \*/ = \{\s*isa = PBXGroup;\s*children = \(\n)([\s\S]*?)(\n\t\t\t\);\s*path = Afterna;)",
            text,
        )
        assert afterna
        text = text[: afterna.start(2)] + afterna.group(2) + "".join(inserts) + text[afterna.end(2) :]

path.write_text(text, encoding="utf-8")
print("updated pbxproj")
