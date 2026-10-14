#!/usr/bin/env bash
set -euo pipefail

TK_REPO="SY227/typekeeper-press-kit"
TK_GH_REPO="github.com/$TK_REPO"
TK_TAG="mac-gameplay-demo"
TK_MEDIA="Typekeeper_Path_to_the_Crown_Mac_Gameplay_Demo.mp4"
TK_PDF="Typekeeper_Apple_Editorial_Preview.pdf"

for TK_TOOL in gh git curl; do
  command -v "$TK_TOOL" >/dev/null || {
    echo "Required command not found: $TK_TOOL"
    exit 1
  }
done

[[ "$(gh api --hostname github.com user --jq '.login')" == "SY227" ]] || {
  echo "Run: gh auth switch --hostname github.com --user SY227"
  exit 1
}

[[ "$(gh repo view "$TK_GH_REPO" --json isPrivate --jq '.isPrivate')" == "false" ]] || {
  echo "The press-kit repository must be public."
  exit 1
}

TK_BRANCH=$(gh api --hostname github.com "repos/$TK_REPO" --jq '.default_branch')
TK_TMP=$(mktemp -d)
trap 'rm -rf "$TK_TMP"' EXIT

tk_git() {
  git -c credential.helper= \
      -c 'credential.https://github.com.helper=!gh auth git-credential' "$@"
}

echo "Preparing the existing GitHub press kit..."
tk_git clone --depth 1 --branch "$TK_BRANCH" \
  "https://github.com/$TK_REPO.git" "$TK_TMP/repo"
cd "$TK_TMP/repo"

[[ -s "$TK_PDF" ]] || {
  echo "The editorial PDF is missing from the repository."
  exit 1
}
[[ "$(head -c 5 "$TK_PDF")" == "%PDF-" ]] || {
  echo "The editorial PDF has an invalid file header."
  exit 1
}

gh release download "$TK_TAG" --repo "$TK_GH_REPO" \
  --pattern "$TK_MEDIA" --dir "$TK_TMP"
[[ -s "$TK_TMP/$TK_MEDIA" ]] || {
  echo "The existing release video could not be downloaded."
  exit 1
}

mkdir -p media
if command -v ffmpeg >/dev/null 2>&1; then
  echo "Preparing a smaller 1080p streaming copy..."
  ffmpeg -hide_banner -loglevel error -i "$TK_TMP/$TK_MEDIA" \
    -map 0:V:0 -map 0:a:0 -vf fps=30 \
    -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p \
    -c:a copy -movflags +faststart -y "media/$TK_MEDIA"
else
  echo "Using the existing 1080p video for browser playback..."
  cp "$TK_TMP/$TK_MEDIA" "media/$TK_MEDIA"
fi

TK_BYTES=$(wc -c < "media/$TK_MEDIA" | tr -d '[:space:]')
[[ "$TK_BYTES" -lt 104857600 ]] || {
  echo "The streaming file exceeds GitHub's regular file limit. Install ffmpeg and rerun."
  exit 1
}

cat > Mac_Gameplay_Demo.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="theme-color" content="#f8f2e7">
  <title>Typekeeper: Path to the Crown — Mac Gameplay Demo</title>
  <meta name="description" content="Watch the 28-second Typekeeper Mac gameplay demo and read the three-page editorial preview.">
  <style>
    *{box-sizing:border-box}body{margin:0;background:#f8f2e7;color:#34251f;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    main{max-width:1120px;margin:auto;padding:26px 24px}header{display:flex;align-items:end;justify-content:space-between;gap:20px;margin-bottom:18px}
    .eyebrow{color:#a8442c;font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;margin:0 0 9px}
    h1{font:normal clamp(29px,4vw,44px)/1.13 Georgia,serif;margin:0}h1 span{display:block;font-size:.66em;margin-top:5px}
    .meta{margin:0;color:#75665d;font-size:13px;line-height:1.6;text-align:right}
    .screen{position:relative;overflow:hidden;border:1px solid #d6c1a1;border-radius:8px;background:#000}
    video{display:block;width:100%;aspect-ratio:16/9;object-fit:contain;background:#000}
    .bar{display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap;align-items:center;padding:16px 0;border-bottom:1px solid #d6c1a1}
    .buttons,.links{display:flex;align-items:center;gap:10px;flex-wrap:wrap}.links{gap:20px}
    button{font:inherit;font-size:13px;font-weight:600;padding:10px 14px;min-height:42px;border-radius:5px;border:1px solid #d6c1a1;background:transparent;color:#34251f;cursor:pointer}
    #sound{background:#a8442c;border-color:#a8442c;color:#fff8ec}a{color:#a8442c;font-size:13px;font-weight:600;text-decoration:none;text-underline-offset:4px}a:hover{text-decoration:underline}
    :focus-visible{outline:3px solid #c78330;outline-offset:4px}[hidden]{display:none!important}
    #play{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);background:#f8f2e7;border-radius:999px;padding:14px 24px;font-size:17px}
    footer{font-size:12px;line-height:1.6;color:#75665d;margin-top:15px}.error{color:#a8442c;font-size:14px;line-height:1.6}
    @media(max-width:640px){main{padding:20px 14px}header{display:block}.meta{text-align:left;margin-top:13px}.bar{gap:18px}}
  </style>
</head>
<body>
<main>
  <p class="eyebrow">FoxForge Studio · Actual Mac gameplay</p>
  <header>
    <h1>Typekeeper<span>Path to the Crown</span></h1>
    <p class="meta">Mac Gameplay Demo<br>28 seconds</p>
  </header>
  <div class="screen">
    <video id="demo" controls autoplay muted playsinline preload="auto" aria-label="Typekeeper Mac gameplay demo">
      <source src="media/Typekeeper_Path_to_the_Crown_Mac_Gameplay_Demo.mp4" type="video/mp4">
      Your browser cannot play this video. Download the original MP4 using the link below.
    </video>
    <button id="play" hidden>▶ Play demo</button>
  </div>
  <p id="error" class="error" role="status" hidden>The video could not load. Download the original MP4 below.</p>
  <div class="bar">
    <div class="buttons">
      <button id="sound" aria-pressed="false">Turn sound on</button>
      <button id="replay">Replay</button>
      <button id="fullscreen">Full screen</button>
    </div>
    <nav class="links" aria-label="Editorial materials">
      <a href="Typekeeper_Apple_Editorial_Preview.pdf#view=FitH" target="_blank" rel="noopener">Open editorial PDF ↗</a>
      <a href="https://github.com/SY227/typekeeper-press-kit/releases/download/mac-gameplay-demo/Typekeeper_Path_to_the_Crown_Mac_Gameplay_Demo.mp4">Download original MP4 ↗</a>
    </nav>
  </div>
  <footer>English typing · ICE spell · Style Shop previews<br>Prepared for App Store editorial consideration.</footer>
</main>
<script>
  const video=document.getElementById('demo'),playButton=document.getElementById('play'),sound=document.getElementById('sound'),replay=document.getElementById('replay'),fullscreen=document.getElementById('fullscreen'),error=document.getElementById('error');
  function play(){const p=video.play();if(p)p.then(()=>{playButton.hidden=true;}).catch(()=>{if(!video.error)playButton.hidden=false;});}
  function syncSound(){sound.textContent=video.muted?'Turn sound on':'Mute sound';sound.setAttribute('aria-pressed',String(!video.muted));}
  playButton.addEventListener('click',play);
  sound.addEventListener('click',()=>{video.muted=!video.muted;if(video.ended)video.currentTime=0;syncSound();if(video.paused)play();});
  replay.addEventListener('click',()=>{video.currentTime=0;play();});
  fullscreen.addEventListener('click',()=>{if(video.requestFullscreen)video.requestFullscreen().catch(()=>{});else if(video.webkitEnterFullscreen)video.webkitEnterFullscreen();});
  if(!video.requestFullscreen&&!video.webkitEnterFullscreen)fullscreen.hidden=true;
  video.addEventListener('playing',()=>{playButton.hidden=true;});
  video.addEventListener('volumechange',syncSound);
  video.addEventListener('ended',()=>{playButton.textContent='↻ Replay demo';playButton.hidden=false;});
  video.addEventListener('error',()=>{error.hidden=false;playButton.hidden=true;sound.disabled=true;replay.disabled=true;fullscreen.disabled=true;});
  video.muted=true;syncSound();play();
</script>
</body>
</html>
HTML

cp Mac_Gameplay_Demo.html index.html
: > .nojekyll

git add -- Mac_Gameplay_Demo.html index.html .nojekyll "media/$TK_MEDIA"
if ! git diff --cached --quiet; then
  git -c user.name='Simon Yam' \
      -c user.email='38198978+SY227@users.noreply.github.com' \
      commit -m "Add Mac gameplay player and direct editorial PDF access"
  tk_git push origin "HEAD:$TK_BRANCH"
fi

printf '{"build_type":"legacy","source":{"branch":"%s","path":"/"}}\n' \
  "$TK_BRANCH" > "$TK_TMP/pages.json"

echo "Configuring GitHub Pages..."
if gh api --hostname github.com "repos/$TK_REPO/pages" >/dev/null 2>&1; then
  gh api --hostname github.com --method PUT "repos/$TK_REPO/pages" \
    --input "$TK_TMP/pages.json" >/dev/null
else
  gh api --hostname github.com --method POST "repos/$TK_REPO/pages" \
    --input "$TK_TMP/pages.json" >/dev/null
fi

TK_BASE=$(gh api --hostname github.com "repos/$TK_REPO/pages" --jq '.html_url')
TK_BASE="${TK_BASE%/}"
[[ "$TK_BASE" == https://* ]] || {
  echo "GitHub did not return an HTTPS Pages URL."
  exit 1
}
TK_DEMO_URL="$TK_BASE/Mac_Gameplay_Demo.html"
TK_PDF_URL="$TK_BASE/$TK_PDF#view=FitH"

echo "Waiting for the public player and PDF (first publication can take several minutes)..."
TK_READY=false
for TK_ATTEMPT in $(seq 1 120); do
  if curl --fail --silent --show-error --location --connect-timeout 5 --max-time 15 \
       "$TK_DEMO_URL" -o "$TK_TMP/live.html" 2>/dev/null \
     && cmp -s Mac_Gameplay_Demo.html "$TK_TMP/live.html" \
     && curl --fail --silent --show-error --head --location --connect-timeout 5 --max-time 15 \
       "$TK_BASE/media/$TK_MEDIA" >/dev/null 2>&1 \
     && curl --fail --silent --show-error --location --connect-timeout 5 --max-time 15 \
       "$TK_BASE/$TK_PDF" -o "$TK_TMP/live.pdf" 2>/dev/null \
     && cmp -s "$TK_PDF" "$TK_TMP/live.pdf"; then
    TK_READY=true
    break
  fi
  if (( TK_ATTEMPT % 12 == 0 )); then
    printf 'Still waiting for GitHub Pages: attempt %s/120\n' "$TK_ATTEMPT"
  fi
  sleep 5
done

if [[ "$TK_READY" != true ]]; then
  printf '\nThe files are uploaded, but Pages is not ready yet.\nPlayer: %s\nPDF: %s\n' \
    "$TK_DEMO_URL" "$TK_PDF_URL"
  echo "Check the Pages build in the repository's Actions tab, then rerun this script."
  exit 1
fi

cat > "$TK_TMP/release-notes.md" <<NOTES
## Watch the Mac gameplay demo

[Play Typekeeper: Path to the Crown in your browser]($TK_DEMO_URL)

A 28-second capture of actual Mac gameplay: English typing challenges, the ICE spell and Style Shop previews. The player starts muted; select **Turn sound on** to hear the game. Use **Full screen** for a larger view.

## Read the editorial preview

[Open the three-page editorial PDF in a full browser window]($TK_PDF_URL)

Actual gameplay, English and Traditional Chinese story scenes, and the complete Mac adventure.

[Download the original 1080p MP4](https://github.com/$TK_REPO/releases/download/$TK_TAG/$TK_MEDIA)
NOTES

gh release edit "$TK_TAG" --repo "$TK_GH_REPO" \
  --title "Typekeeper: Path to the Crown - Mac Gameplay Demo & Editorial Preview" \
  --notes-file "$TK_TMP/release-notes.md"

printf '\nVerified public links for Apple Supplemental Materials:\n\nGameplay demo:\n%s\n\nFull-window PDF:\n%s\n\nUpdated release page:\nhttps://github.com/%s/releases/tag/%s\n' \
  "$TK_DEMO_URL" "$TK_PDF_URL" "$TK_REPO" "$TK_TAG"
if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$TK_DEMO_URL" | pbcopy
  echo "Gameplay link copied to clipboard."
fi
if command -v open >/dev/null 2>&1; then
  open "$TK_DEMO_URL"
fi
