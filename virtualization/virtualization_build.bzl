"""
Reusable macro for virtualization build rules.
"""

load("@score_toolchains_qnx//rules/fs:ifs.bzl", "qnx_ifs")

def virtualization_build(
    name,
    srcs,
    overlay_srcs = [],
    qnx_ifs_outs = None,
    build_file_x86_64 = "@score_virtualization//virtualization:init_x86_64.build",
    build_file_aarch64 = "@score_virtualization//virtualization:init_rpi4.build",
    run_qemu_sh = "@score_virtualization//virtualization:run_qemu.sh",
    qemu_bin = "@custom_qemu//:qemu_bin",
    rpi4_dtb = "@custom_qemu//:rpi4_dtb",
    host_dir = "@toolchains_qnx_sdp//:host_dir",
    host_all = "@toolchains_qnx_sdp//:host_all",
    init_script = None,
    disable = False
):
    if disable:
        return
    native.config_setting(
        name = name + "_is_qnx_x86_64",
        constraint_values = [
            "@platforms//cpu:x86_64",
            "@platforms//os:qnx",
        ],
    )

    native.config_setting(
        name = name + "_is_qnx_aarch64",
        constraint_values = [
            "@platforms//cpu:aarch64",
            "@platforms//os:qnx",
        ],
    )

    init_script_out = "custom_internal/" + "startup_script" if init_script != None else None

    install_targets(
        name = name + "install_all",
        targets = srcs + ([init_script] if init_script != None else []),
        install_dir = "custom",  # output directory
    )

    native.genrule(
        name = name + "startup_script",
        srcs = [init_script],          # the file you want to copy
        outs = [init_script_out],          # the destination filename
        cmd = "cp $(SRCS) $@",          # $@ is the output file
    )

    native.filegroup(
        name = name + "_overlay_tree",
        srcs = [":check_git_lfs"] + overlay_srcs + ["@score_virtualization//virtualization:baseline_image_install_files"],
        visibility = ["//visibility:public"],
    )

    qnx_ifs(
        name = name + "_init",
        srcs = select({
            ":" + name + "_is_qnx_aarch64": [
                ":" + name + "_overlay_tree",
                ":" + name + "startup_script",
                ":" + name + "install_all"
            ],
            "//conditions:default": [],
        }),
        out = select({
            ":" + name + "_is_qnx_x86_64": qnx_ifs_outs[0] if qnx_ifs_outs else "init_x86_64.ifs",
            ":" + name + "_is_qnx_aarch64": qnx_ifs_outs[1] if qnx_ifs_outs else "init_aarch64.ifs",
            "//conditions:default": "dd",
        }),
        build_file = select({
            ":" + name + "_is_qnx_x86_64": build_file_x86_64,
            ":" + name + "_is_qnx_aarch64": build_file_aarch64,
            "//conditions:default": "dd",
        }),
        search_roots = select({
            ":" + name + "_is_qnx_aarch64": ["install"],
            "//conditions:default": [],
        }),
    )

    native.sh_binary(
        name = name + "_run_qemu",
        srcs = [run_qemu_sh],
        args = [
            "$(location " + host_dir + ")",
            "$(location :" + name + "_init)",
            "$(location " + qemu_bin + ")",
            "$(location " + rpi4_dtb + ")",
        ],
        data = [
            ":" + name + "_init",
            qemu_bin,
            rpi4_dtb,
            host_all,
            host_dir,
        ],
    )

    native.genrule(
        name = "check_git_lfs",
        outs = ["git_lfs_check.txt"],
        cmd = """
            if ! command -v git-lfs >/dev/null 2>&1; then
                echo "ERROR: git-lfs not found. Please install Git LFS." >&2
                exit 1
            fi
            echo "Git LFS is installed." > $@
        """,
    )

def _install_targets_impl(ctx):
    install_dir = ctx.actions.declare_directory(ctx.attr.install_dir)

    # Merge all runfiles from targets
    all_files = depset(transitive=[dep[DefaultInfo].default_runfiles.files for dep in ctx.attr.targets])

    cmd_lines = [
        "set -euo pipefail",
        "dest_dir='{}'".format(install_dir.path),
        "mkdir -p \"$dest_dir\"",
    ]

    for f in all_files.to_list():
        cmd_lines.append("mkdir -p \"$dest_dir/$(dirname {})\"".format(f.short_path))
        cmd_lines.append("cp {} \"$dest_dir/{}\"".format(f.path, f.short_path))

    ctx.actions.run_shell(
        inputs=all_files,
        outputs=[install_dir],
        command="\n".join(cmd_lines),
    )

    return [DefaultInfo(files=depset([install_dir]))]


install_targets = rule(
    implementation=_install_targets_impl,
    attrs={
        "targets": attr.label_list(allow_files=True),          # targets to install
        "install_dir": attr.string(),          # name of output directory
    },
)