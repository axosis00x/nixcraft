#!/usr/bin/env bash
# nixcraft release: bumps VERSION, writes the CHANGELOG.md entry from the
# Conventional Commits since the last tag, then commits and tags the version.
# Pushing the tag makes the release workflow publish a GitHub release.
#
# Versions are X.Y.Z while stable, or X.Y.Z-PHASE.N during a pre-release
# phase, in order: pre-alpha, alpha, beta, rc, then stable.
#
#   scripts/release.sh                 next release in the current phase (0.1.0-alpha.1 → 0.1.0-alpha.2;
#                                      when stable, bump from the commits: feat → minor, fix → patch, ! → major)
#   scripts/release.sh minor           force major | minor | patch, or give X.Y.Z / X.Y.Z-PHASE.N
#   scripts/release.sh --phase beta    move to a phase (0.1.0-alpha.3 → 0.1.0-beta.1; "stable" → 0.1.0)
#   scripts/release.sh --dry-run       print the entry and version, change nothing
#   scripts/release.sh --push          also push the commit and tag to origin
#   scripts/release.sh notes [VERSION] print a version's CHANGELOG.md entry (default: VERSION file)
set -euo pipefail

# Work from the repo root, one level above scripts/.
cd "$(dirname "$0")/.."

phases=(pre-alpha alpha beta rc stable)

bump=""
phase=""
dry_run=false
push=false
notes=false
while (($#)); do
    case "$1" in
        major | minor | patch) bump=$1 ;;
        [0-9]*.[0-9]*.[0-9]*) bump=$1 ;;
        notes) notes=true ;;
        --phase) phase=${2:-} && shift ;;
        --phase=*) phase=${1#--phase=} ;;
        -n | --dry-run) dry_run=true ;;
        -p | --push) push=true ;;
        -h | --help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (see --help)" >&2
            exit 2
            ;;
    esac
    shift
done

bold=$'\033[1m' dim=$'\033[2m' green=$'\033[32m' yellow=$'\033[33m' red=$'\033[31m' reset=$'\033[0m'
info() { printf '%s==>%s %s\n' "$green" "$reset" "$1"; }
warn() { printf '%s!!%s  %s\n' "$yellow" "$reset" "$1"; }
die() {
    printf '%sxx%s  %s\n' "$red" "$reset" "$1" >&2
    exit 1
}

semver='^([0-9]+\.[0-9]+\.[0-9]+)(-(pre-alpha|alpha|beta|rc)\.([1-9][0-9]*))?$'

# phase_rank PHASE: its position in the phases list (stable is last).
phase_rank() {
    local i
    for i in "${!phases[@]}"; do
        [[ ${phases[i]} == "$1" ]] && echo "$i" && return
    done
    die "Unknown phase: $1 (one of: ${phases[*]})"
}

# split VERSION: sets base, ver_phase ("stable" when there is none) and n.
split() {
    [[ $1 =~ $semver ]] || die "Not X.Y.Z or X.Y.Z-PHASE.N: $1"
    base=${BASH_REMATCH[1]} ver_phase=${BASH_REMATCH[3]:-stable} n=${BASH_REMATCH[4]:-0}
}

# newer A B: whether A comes after B (by base, then phase, then number).
newer() {
    local a_base a_rank a_n
    split "$1"
    a_base=$base a_rank=$(phase_rank "$ver_phase") a_n=$n
    split "$2"
    [[ $a_base != "$base" ]] && {
        [[ $(printf '%s\n%s\n' "$a_base" "$base" | sort -V | tail -1) == "$a_base" ]]
        return
    }
    local b_rank
    b_rank=$(phase_rank "$ver_phase")
    ((a_rank > b_rank || (a_rank == b_rank && a_n > n)))
}

current=$(tr -d '[:space:]' <VERSION 2>/dev/null || true)
current=${current:-0.0.0}
[[ $current =~ $semver ]] || die "VERSION is not X.Y.Z or X.Y.Z-PHASE.N: $current"
[[ -z $phase ]] || phase_rank "$phase" >/dev/null

# notes [VERSION]: the body of that version's "## [VERSION]" section.
if $notes; then
    version=${bump:-$current}
    [[ $version =~ $semver ]] || die "notes takes a version, not $version"
    body=$(awk -v v="$version" '
        /^## \[/ { if (found) exit; found = index($0, "## [" v "]") == 1; next }
        found' CHANGELOG.md | sed -e '/./,$!d' -e :a -e '/^\n*$/{$d;N;ba' -e '}')
    [[ -n $body ]] || die "CHANGELOG.md has no entry for $version"
    printf '%s\n' "$body"
    exit 0
fi

git diff --quiet && git diff --cached --quiet ||
    die "Commit or stash your changes first; a release only contains committed work."

last_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
range=${last_tag:+$last_tag..}HEAD

# One "hash<TAB>subject<TAB>breaking" line per commit (breaking is 1 when the
# body has a BREAKING CHANGE footer), skipping merges and release commits.
breaking=$(git log --no-merges --format='%h' -E --grep='^BREAKING[ -]CHANGE:' "$range")
commits=$(git log --no-merges --format='%h%x09%s' "$range" |
    awk -F'\t' -v breaking="$breaking" '
        BEGIN { n = split(breaking, list, "\n"); for (i = 1; i <= n; i++) b[list[i]] = 1 }
        $2 !~ /^chore\(release\)/ { print $1 "\t" $2 "\t" ($1 in b ? 1 : 0) }')

[[ -n $commits || -z $last_tag ]] || die "Nothing to release since $last_tag."

split "$current"
cur_base=$base cur_phase=$ver_phase cur_n=$n
target=${phase:-$cur_phase}

if [[ $bump =~ $semver ]]; then
    # An exact version; a bare X.Y.Z joins the --phase (or current) phase.
    version=$bump
    [[ -n ${BASH_REMATCH[2]} || $target == stable ]] || version="$bump-$target.1"
elif [[ -z $bump && $cur_phase != stable ]]; then
    # Within a pre-release phase the X.Y.Z stays put: the next release in
    # the same phase counts up, a later phase starts again at 1.
    (($(phase_rank "$target") >= $(phase_rank "$cur_phase"))) ||
        die "Can't go back from $cur_phase to $target; bump the version to start a new cycle."
    if [[ $target == "$cur_phase" ]]; then
        version="$cur_base-$cur_phase.$((cur_n + 1))"
    elif [[ $target == stable ]]; then
        version=$cur_base
    else
        version="$cur_base-$target.1"
    fi
else
    # Bump from the commits unless one was given: any breaking change is
    # major, any feat is minor, anything else is a patch.
    if [[ -z $bump ]]; then
        if grep -qP '^\S+\t[a-z]+(\([^)]*\))?!:|\t1$' <<<"$commits"; then
            bump="major"
        elif grep -qP '^\S+\tfeat(\([^)]*\))?:' <<<"$commits"; then
            bump="minor"
        else
            bump="patch"
        fi
    fi
    IFS=. read -r major minor patch <<<"$cur_base"
    case "$bump" in
        major) version="$((major + 1)).0.0" ;;
        minor) version="$major.$((minor + 1)).0" ;;
        patch) version="$major.$minor.$((patch + 1))" ;;
    esac
    [[ $target == stable ]] || version="$version-$target.1"
fi

split "$version"
version_phase=$ver_phase
tag="v$version"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "Tag $tag already exists."
newer "$version" "$current" || die "$version is not newer than $current."

# Group the commits by type, in this order, as "- **scope:** subject (hash)".
sections=(
    "feat|Features"
    "fix|Fixes"
    "perf|Performance"
    "refactor|Refactors"
    "style|Style"
    "docs|Documentation"
    "build|Build"
    "ci|CI"
    "chore|Chores"
    "revert|Reverts"
)

render_entry() {
    printf '## [%s] - %s\n' "$version" "$(date +%F)"
    if [[ -z $last_tag ]]; then
        printf '\nFirst tagged release.\n'
        return
    fi
    if grep -qP '^\S+\t[a-z]+(\([^)]*\))?!:|\t1$' <<<"$commits"; then
        printf '\n### Breaking changes\n\n'
        grep -P '^\S+\t[a-z]+(\([^)]*\))?!:|\t1$' <<<"$commits" | format_lines
    fi
    local entry type title lines
    for entry in "${sections[@]}"; do
        type=${entry%%|*} title=${entry#*|}
        lines=$(grep -P "^\S+\t$type(\([^)]*\))?!?:" <<<"$commits" || true)
        [[ -n $lines ]] || continue
        printf '\n### %s\n\n' "$title"
        format_lines <<<"$lines"
    done
    lines=$(grep -Pv '^\S+\t(feat|fix|perf|refactor|style|docs|build|ci|chore|revert)(\([^)]*\))?!?:' <<<"$commits" || true)
    if [[ -n $lines ]]; then
        printf '\n### Other\n\n'
        format_lines <<<"$lines"
    fi
}

format_lines() {
    awk -F'\t' '{
        subject = $2
        scope = ""
        if (match(subject, /^[a-z]+\([^)]*\)!?: /)) {
            scope = subject
            sub(/^[a-z]+\(/, "", scope)
            sub(/\).*/, "", scope)
        }
        sub(/^[a-z]+(\([^)]*\))?!?: /, "", subject)
        printf "- %s%s (%s)\n", (scope != "" ? "**" scope ":** " : ""), subject, $1
    }'
}

entry=$(render_entry)

info "Releasing ${bold}$tag${reset}, $version_phase (was $current, ${last_tag:-no earlier tag})"
printf '%s\n' "$entry" | sed "s/^/${dim}    │${reset} /"

if $dry_run; then
    warn "Dry run: nothing was changed."
    exit 0
fi

# The new entry goes above the newest one, below the file's header.
header=$(awk '/^## \[/ { exit } { print }' CHANGELOG.md 2>/dev/null || true)
older=$(awk 'found || /^## \[/ { found = 1; print }' CHANGELOG.md 2>/dev/null || true)
[[ -n $header ]] || header="# Changelog"
{
    printf '%s\n\n%s\n' "$(sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' <<<"$header")" "$entry"
    [[ -z $older ]] || printf '\n%s\n' "$older"
} >CHANGELOG.md
printf '%s\n' "$version" >VERSION

git add VERSION CHANGELOG.md
git commit -q -m "chore(release): $tag"
git tag -a "$tag" -m "nixcraft $tag ($version_phase)"
info "Committed and tagged $tag."

if $push; then
    git push --atomic origin HEAD "$tag"
    info "Pushed; the release workflow will publish $tag."
else
    info "Push it with: ${bold}git push --atomic origin HEAD $tag${reset}"
fi
