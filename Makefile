# Backward-compatible Makefile wrapper delegating to Taskfile (go-task)
.DEFAULT_GOAL := help

.PHONY: help
help:
	@task --list

%:
	@task $@
