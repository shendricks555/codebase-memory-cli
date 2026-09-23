# cli-only.mk — fork F4: CLI-only shippable binary (CBM_FORK_CLI_ONLY).
#
# Included from Makefile.cbm (one `include` line). Purely additive: nothing here
# is a prerequisite of `cbm`, `cbm-with-ui`, `test`, or any default target, and
# $(PROD_SRCS) is untouched.
#
# Source set: PROD_SRCS minus the daemon runtime/frontend TUs. Retained from
# src/daemon: bootstrap.c (argv role classifier), project_lock.c (mutation
# serialization) and ipc.c (cbm_daemon_ipc_private_lock_directory_new, the one
# helper project_lock needs). Their unreferenced socket/coordination code is
# removed at link time by section GC (plan T4.3 option 1, zero src/daemon
# edits). verify-cli-only-link is the arbiter.
#
# Only the fork-owned edges (src/main.c, src/cli/cli.c) take the guard, as in
# cbm-fork-verify: src/ui/http_server.c calls cbm_mcp_server_handle, so mcp.c
# stays unguarded. The guard only fences function declarations, so mixing
# guarded and unguarded objects is ABI-safe.
#
# E8: CFLAGS_PROD with the test-seam define filtered out — never seams.

CLI_ONLY_BIN = $(BUILD_DIR)/codebase-memory-cli
CLI_ONLY_DROPPED_DAEMON_SRCS = \
    src/daemon/daemon.c \
    src/daemon/version_cohort.c \
    src/daemon/runtime.c \
    src/daemon/application.c \
    src/daemon/frontend.c \
    src/daemon/host.c
CLI_ONLY_REST_SRCS = $(filter-out src/cli/cli.c $(CLI_ONLY_DROPPED_DAEMON_SRCS),$(PROD_SRCS)) \
    $(EXTRACTION_SRCS) $(AC_LZ4_SRCS) $(ZSTD_SRCS) $(SQLITE_WRITER_SRC)
CLI_ONLY_MAIN_OBJ = $(BUILD_DIR)/cli_only_main.o
CLI_ONLY_CLI_OBJ = $(BUILD_DIR)/cli_only_cli.o
CLI_ONLY_SECTION_CFLAGS = -ffunction-sections -fdata-sections
ifeq ($(shell uname -s),Darwin)
CLI_ONLY_GC_LDFLAGS = -Wl,-dead_strip
else
CLI_ONLY_GC_LDFLAGS = -Wl,--gc-sections
endif
CLI_ONLY_CFLAGS = $(filter-out -DCBM_ENABLE_TEST_SEAMS=1,$(CFLAGS_PROD)) $(CLI_ONLY_SECTION_CFLAGS)
# Guarded main.c compiles out the daemon/hook/worker/MCP role paths; their
# static helpers become unreferenced and are discarded by the compiler. Relax
# only those two diagnostics, only for the two guarded fork-edge TUs, rather
# than wrapping ~20 upstream helpers in #ifndef (keeps the main.c diff small).
CLI_ONLY_EDGE_CFLAGS = $(CLI_ONLY_CFLAGS) -Wno-unused-function -Wno-unused-variable

.PHONY: cbm-cli verify-cli-only-link

cbm-cli: $(OBJS_VENDORED_PROD) $(PROJECT_HDRS) | $(BUILD_DIR)
	@echo "=== cbm-cli: compiling src/main.c + src/cli/cli.c with -DCBM_FORK_CLI_ONLY=1 ==="
	$(CC) $(CLI_ONLY_EDGE_CFLAGS) -DCBM_FORK_CLI_ONLY=1 -c -o $(CLI_ONLY_MAIN_OBJ) src/main.c
	$(CC) $(CLI_ONLY_EDGE_CFLAGS) -DCBM_FORK_CLI_ONLY=1 -c -o $(CLI_ONLY_CLI_OBJ) src/cli/cli.c
	@echo "=== linking $(CLI_ONLY_BIN) (daemon runtime/frontend dropped, section GC) ==="
	$(CC) $(CLI_ONLY_CFLAGS) -o $(CLI_ONLY_BIN) \
		$(CLI_ONLY_MAIN_OBJ) $(CLI_ONLY_CLI_OBJ) \
		$(CLI_ONLY_REST_SRCS) \
		$(OBJS_VENDORED_PROD) \
		$(LDFLAGS) $(CLI_ONLY_GC_LDFLAGS)
	@rm -f $(CLI_ONLY_MAIN_OBJ) $(CLI_ONLY_CLI_OBJ)
	@echo "Built: $(CLI_ONLY_BIN)"

# F4 link-isolation gate (E2, E8). Verification-only; not in default/prod.
# Asserts on the linked binary: (a) no dropped daemon runtime/frontend symbols,
# (b) no ipc.c daemon-socket/coordination entry points, (c) no *test_seam*
# symbols; and that the engine, project_lock and classifier are present. The
# loopback UI listener (src/ui) is the only permitted socket user, so libc
# socket imports are not asserted here (F6 audits the UI).
CLI_ONLY_FORBIDDEN_PREFIXES = cbm_daemon_runtime_ cbm_daemon_frontend_ cbm_daemon_host_ \
    cbm_daemon_application_ cbm_daemon_service_ cbm_version_cohort_ \
    cbm_daemon_maintenance_monitor_ cbm_daemon_ipc_listen cbm_daemon_ipc_accept \
    cbm_daemon_ipc_connect cbm_daemon_ipc_startup_lock_ cbm_daemon_ipc_local_transition_ \
    cbm_daemon_ipc_lifetime_reservation_ cbm_mcp_server_run
CLI_ONLY_REQUIRED_SYMS = cbm_mcp_handle_tool cbm_project_lock_manager_new cbm_daemon_process_role
CLI_ONLY_SYMS = $(BUILD_DIR)/cli_only_syms.txt

verify-cli-only-link: cbm-cli
	@echo "=== verify-cli-only-link: nm $(CLI_ONLY_BIN) ==="
	@nm "$(CLI_ONLY_BIN)" | awk '$$2 ~ /^[TtDdBbSs]$$/ {sub(/^_/, "", $$3); print $$3}' > $(CLI_ONLY_SYMS)
	@fail=0; \
	for p in $(CLI_ONLY_FORBIDDEN_PREFIXES); do \
		hits=$$(grep -E "^$$p" $(CLI_ONLY_SYMS) | head -5); \
		if [ -n "$$hits" ]; then echo "  FAIL: forbidden '$$p*' linked:"; echo "$$hits" | sed 's/^/      /'; fail=1; \
		else echo "  ok absent: $$p*"; fi; \
	done; \
	seams=$$(grep -i "test_seam" $(CLI_ONLY_SYMS) | head -5); \
	if [ -n "$$seams" ]; then echo "  FAIL: test seam symbols linked:"; echo "$$seams"; fail=1; \
	else echo "  ok absent: *test_seam*"; fi; \
	for sym in $(CLI_ONLY_REQUIRED_SYMS); do \
		if grep -qx "$$sym" $(CLI_ONLY_SYMS); then echo "  ok present: $$sym"; \
		else echo "  FAIL: required symbol missing: $$sym"; fail=1; fi; \
	done; \
	rm -f $(CLI_ONLY_SYMS); \
	if [ $$fail -ne 0 ]; then exit 1; fi
	@echo "verify-cli-only-link: PASS"

