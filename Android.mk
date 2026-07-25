LOCAL_PATH := $(call my-dir)

# Build the Konoha GKI kernel from source and refresh the prebuilt Image
# that BoardConfig.mk's PRODUCT_COPY_FILES rule packages into boot.img.
# The script no-ops if the kernel source isn't checked out, so this is
# safe to keep wired in unconditionally.
KONOHA_KERNEL_SRC := device/xiaomi/onyx-konoha
KONOHA_KERNEL_IMAGE := $(PREBUILT_PATH)/images/kernel

.PHONY: konoha_kernel
konoha_kernel:
	bash $(LOCAL_PATH)/build_konoha_kernel.sh $(KONOHA_KERNEL_SRC) $(KONOHA_KERNEL_IMAGE)

$(KONOHA_KERNEL_IMAGE): konoha_kernel

droidcore: konoha_kernel
