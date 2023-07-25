#!/bin/bash
set -e
curl -Lo - https://crowdin.com/backend/download/project/wireguard.zip | bsdtar -C Sources/SpaceNetClient -x -f - --strip-components 3 wireguard-apple
find Sources/SpaceNetClient/*.lproj -type f -empty -delete
find Sources/SpaceNetClient/*.lproj -type d -empty -delete
declare -A ALL_BASE
while read -r key eq rest; do
	[[ $key == \"* && $key == *\" && $eq == = ]] || continue
	ALL_BASE["$key"]="$rest"
done < Sources/SpaceNetClient/Base.lproj/Localizable.strings
for f in Sources/SpaceNetClient/*.lproj/Localizable.strings; do
	unset FOUND
	declare -A FOUND
	while read -r key eq _; do
		[[ $key == \"* && $key == *\" && $eq == = ]] || continue
		FOUND["$key"]=1
	done < "$f"
	for key in "${!ALL_BASE[@]}"; do
		[[ ${FOUND["$key"]} -eq 1 ]] && continue
		echo "$key = ${ALL_BASE["$key"]}"
	done >> "$f"
done < Sources/SpaceNetClient/Base.lproj/Localizable.strings
git add Sources/SpaceNetClient/*.lproj

declare -A LOCALE_MAP
[[ $(< SpaceNetClient.xcodeproj/project.pbxproj) =~ [[:space:]]([0-9A-F]{24})\ /\*\ Base\ \*/\ =\ [^$'\n']*Base\.lproj/Localizable\.strings ]]
base_id="${BASH_REMATCH[1]:0:16}"
idx=$(( "0x${BASH_REMATCH[1]:16}" ))
while read -r filename; do
	l="$(basename "$(dirname "$filename")" .lproj)"
	[[ $l == Base ]] && continue
	((++idx))
	LOCALE_MAP["$l"]="$(printf '%s%08X' "$base_id" $idx)"
done < <(find Sources/SpaceNetClient -name Localizable.strings -type f)

inkr=0 inls=0 inlsc=0
while IFS= read -r line; do
	if [[ $line == *"name = Base; path = Sources/SpaceNetClient/Base.lproj/Localizable.strings"* ]]; then
		echo "$line"
		for l in "${!LOCALE_MAP[@]}"; do
			printf '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = %s; path = Sources/SpaceNetClient/%s.lproj/Localizable.strings; sourceTree = "<group>"; };\n' "${LOCALE_MAP["$l"]}" "$l" "$l" "$l"
		done
	elif [[ $line == *"; path = Sources/SpaceNetClient/"*".lproj/Localizable.strings"* ]]; then
		continue
	elif [[ $line == *"knownRegions = ("* ]]; then
		echo "$line"
		printf '\t\t\t\tBase,\n\t\t\t\ten,\n'
		for l in "${!LOCALE_MAP[@]}"; do
			[[ $l == *-* ]] && l="\"$l\""
			printf '\t\t\t\t%s,\n' "$l"
		done
		inkr=1
	elif [[ $inkr -eq 1 && $line == *");"* ]]; then
		echo "$line"
		inkr=0
	elif [[ $inkr -eq 1 ]]; then
		continue
	elif [[ $inls -eq 0 && $line == *"/* Localizable.strings */ = {"* ]]; then
		echo "$line"
		inls=1
	elif [[ $inls -eq 1 && $inlsc -eq 0 && $line == *"children = ("* ]]; then
		echo "$line"
		inlsc=1
		for l in "${!LOCALE_MAP[@]}"; do
			printf '\t\t\t\t%s /* %s */,\n' "${LOCALE_MAP["$l"]}" "$l"
		done
	elif [[ $inls -eq 1 && $inlsc -eq 1 && $line == *");"* ]]; then
		echo "$line"
		inlsc=0
	elif [[ $inls -eq 1 && $inlsc -eq 0 && $line == *"};"* ]]; then
		echo "$line"
		inls=0
	elif [[ $inls -eq 1 && $inlsc -eq 1 && $line != *" Base "* ]]; then
		continue
	else
		echo "$line"
	fi
done < SpaceNetClient.xcodeproj/project.pbxproj > SpaceNetClient.xcodeproj/project.pbxproj.new
mv SpaceNetClient.xcodeproj/project.pbxproj.new SpaceNetClient.xcodeproj/project.pbxproj
git add SpaceNetClient.xcodeproj/project.pbxproj
