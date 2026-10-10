#!/usr/bin/env bash
# shellcheck disable=SC2034
# The product skills, in routing order, defined once. check-skills, the bundle
# build and their tests read this list instead of repeating it.
CF_PRODUCT_SKILLS='start-here handle-corrections develop-org develop-bounded-context setup-individual validate-and-generate'
# The only product skill that declares no scripts folder, and so needs no wrapper.
CF_SKILLS_WITHOUT_SCRIPTS='start-here'
