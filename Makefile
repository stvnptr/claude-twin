.PHONY: lint test package clean

lint:
	shellcheck scripts/*.sh tests/*.sh

test:
	bash tests/test.sh

# The .skill package contains only what the skill needs at runtime.
package:
	rm -rf dist && mkdir -p dist/claude-twin
	cp -R SKILL.md scripts dist/claude-twin/
	cd dist && zip -rq claude-twin.skill claude-twin -x '*.DS_Store'
	@echo "Built dist/claude-twin.skill"

clean:
	rm -rf dist
