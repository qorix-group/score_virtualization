"""
Reusable macro for virtualization build rules.
"""

load("@score_toolchains_qnx//rules/fs:ifs.bzl", "qnx_ifs")

def virtualization_build(
    name,
    srcs,
    outs,
    overlay_srcs = [],
    qnx_ifs_outs = None,
    build_file_x86_64 = "@score_virtualization//virtualization:init_x86_64.build",
    build_file_aarch64 = "@score_virtualization//virtualization:init_rpi4.build",
    run_qemu_sh = "@score_virtualization//virtualization:run_qemu.sh",
    qemu_bin = "@custom_qemu//:qemu_bin",
    rpi4_dtb = "@custom_qemu//:rpi4_dtb",
    host_dir = "@toolchains_qnx_sdp//:host_dir",
    host_all = "@toolchains_qnx_sdp//:host_all",
    init_script = None,  # Path to optional init script to install
):
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

    native.genrule(
            name = name + "_stage_build_artefacts",
            srcs = srcs,
            outs = outs,
            cmd = """
                set -e
                srcs=($(SRCS))
                outs=($(OUTS))

                for i in $${!srcs[@]}; do
                    out=$${outs[$$i]}
                    mkdir -p "$$(dirname \"$$out\")"
                    cp "$${srcs[$$i]}" "$$out"
                    chmod +x "$$out"
                done
            """,
            visibility = ["//visibility:public"],
    )

    # Optionally install an init_script into the image
    init_script_out = None
    if init_script:
            init_script_out = name + "_init_script_installed"
            native.genrule(
                    name = init_script_out,
                    srcs = [init_script],
                    outs = ["install/boot/sys/startup-custom"],
                    cmd = "cp $< $@ && chmod +x $@",
                    visibility = ["//visibility:public"],
            )

    overlay_files = overlay_srcs + ["@score_virtualization//virtualization:baseline_image_install_files"]
    if init_script_out:
            overlay_files.append(":install/boot/sys/startup-custom")

    native.filegroup(
            name = name + "_overlay_tree",
            srcs = overlay_files,
            visibility = ["//visibility:public"],
    )

    qnx_ifs(
        name = name + "_init",
        srcs = select({
            ":" + name + "_is_qnx_aarch64": [
                ":" + name + "_overlay_tree",
                ":" + name + "_stage_build_artefacts",
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