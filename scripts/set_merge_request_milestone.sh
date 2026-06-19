#!/usr/bin/env bash

source /app/api/gitlab_api.sh

case "$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" in
release/*)
	VER="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME#release/}"

	TAGS=$(gitlab_api GET "/repository/tags" --data-urlencode "search=^${VER}" --data-urlencode "per_page=100" | tee tags.json |
		jq -r '.[].name')

	MS_ID=$(gitlab_api GET "/milestones" --data-urlencode "state=active" --data-urlencode "per_page=100" | tee milestones.json |
		jq -r --arg tags "$TAGS" --arg ver "$VER" --arg prefix "${CI_PROJECT_TITLE} " '
			($tags | split("\n") | map(select(length > 0))) as $t
			| "^\($ver)(\\.[0-9]+)?$" as $pat
			| [.[]
					| select(.title | startswith($prefix))
					| {id, version: (.title | ltrimstr($prefix))}
					| select(.version | test($pat))
					| select(.version as $v | $t | index($v) | not)]
			| sort_by(.version | split(".") | map(tonumber))
			| .[0].id // empty')
	;;
develop)
	RELEASED=$(gitlab_api GET "/repository/branches" --data-urlencode "search=^release/" --data-urlencode "per_page=100" | tee released.json |
		jq -r '.[].name | sub("^release/"; "")')

	MS_ID=$(gitlab_api GET "/milestones" --data-urlencode "state=active" --data-urlencode "per_page=100" | tee milestones.json |
		jq -r --arg released "$RELEASED" --arg prefix "${CI_PROJECT_TITLE} " '
			($released | split("\n") | map(select(length > 0))) as $r
			| [.[]
					| select(.title | startswith($prefix))
					| {id, version: (.title | ltrimstr($prefix))}
					| select(.version | test("^[0-9]+(\\.[0-9]+)+$"))
					| select((.version | split(".")[:2] | join(".")) as $minor | $r | index($minor) | not)]
			| sort_by(.version | split(".") | map(tonumber))
			| .[0].id // empty')
	;;
*)
	echo "Unsupported target branch: $CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
	exit 0
	;;
esac

[ -z "$MS_ID" ] && {
	echo "No suitable milestone found for target $CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
	exit 0
}

gitlab_api PUT "/merge_requests/${CI_MERGE_REQUEST_IID}" --form "milestone_id=${MS_ID}" --fail-with-body
