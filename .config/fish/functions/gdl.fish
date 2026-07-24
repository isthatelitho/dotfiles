function gdl --description 'Download a doujin via gallery-dl, packaged as a .cbz'
    # --- Edit this to match your actual drive layout ---
    set -l doujin_dir "/run/media/eli/1TB/Doujins"
    # -----------------------------------------------------

    if test (count $argv) -lt 1
        echo "Usage: gdl <url>"
        return 1
    end

    set -l url $argv[1]
    set -l dest $doujin_dir

    mkdir -p "$dest"

    set -l name
    read -l -P "Title for this doujin (leave blank to auto-derive from URL): " name

    if test -z "$name"
        set name (python3 "$HOME/.local/bin/gdl-slug.py" "$url")
    else
        set name (string replace -ra '[\\/:*?"<>|]' '-' -- "$name")
    end

    set -l tmp (mktemp -d -p "$dest" .gdl_tmp.XXXXXX)

    gallery-dl -D "$tmp" -o "directory=[]" "$url"
    set -l gdl_status $status

    if test $gdl_status -ne 0
        echo "gallery-dl failed for $url"
        rm -rf "$tmp"
        return 1
    end

    if test (count (find "$tmp" -type f)) -eq 0
        echo "No files downloaded for $url"
        rm -rf "$tmp"
        return 1
    end

    set -l archive_dir "$dest/$name"
    set -l n 2
    while test -e "$archive_dir"
        set archive_dir "$dest/$name ($n)"
        set n (math $n + 1)
    end
    mkdir -p "$archive_dir"
    set -l archive "$archive_dir/$name.cbz"

    pushd "$tmp" > /dev/null
    zip -qr "$archive" .
    popd > /dev/null
    rm -rf "$tmp"
    echo "Created: $archive"

    echo "Done: $url -> $dest"
end
