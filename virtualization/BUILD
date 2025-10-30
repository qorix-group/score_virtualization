exports_files(["virtualization_build.bzl", "run_qemu.sh", "init_x86_64.build", "init_rpi4.build"] + glob(["install/**"]))

filegroup(
    name = "baseline_image_install_files",
    srcs = glob(["install/**"]),
    visibility = ["//visibility:public"],
)