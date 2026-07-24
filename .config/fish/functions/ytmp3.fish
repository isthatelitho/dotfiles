function ytmp3 --description 'Download audio from YouTube in high quality'
    if test (count $argv) -lt 1
        echo "Usage: ytmp3 <url> [output_dir]"
        return 1
    end
    
    set -l url $argv[1]
    set -l outdir (test (count $argv) -ge 2; and echo $argv[2]; or echo ".")
    
    yt-dlp \
                -x --audio-format flac --audio-quality 0 \
                --embed-thumbnail --embed-metadata --embed-chapters \
                --add-metadata \
                --output "$outdir/%(uploader)s - %(title)s.%(ext)s" \
                --restrict-filenames \
                $url
end
