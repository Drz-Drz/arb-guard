// SPDX-License-Identifier: GPL-2.0
/*
 * ARB Guard - Minimal LSM blocking writes to /sys/kernel/dload/update_arb
 * (anti ARB-fuse burn; keep EDL 9008 alive)
 *
 * Blocks:
 *  1. open(/sys/kernel/dload/update_arb, O_WRONLY|O_RDWR) [sysfs kernfs]
 *  2. write on an already-open fd (file_permission MAY_WRITE)
 *  3. bind-mount over /sys/kernel/dload/ (sb_mount)
 */
#include <linux/module.h>
#include <linux/init.h>
#include <linux/security.h>
#include <linux/lsm_hooks.h>
#include <linux/fs.h>
#include <linux/namei.h>
#include <linux/mount.h>
#include <linux/dcache.h>
#include <linux/version.h>
#include <linux/errno.h>
#include <linux/string.h>

static bool str_has_arb(const char *p)
{
	if (!p)
		return false;
	return strstr(p, "dload") && strstr(p, "update_arb");
}

static bool dentry_is_arb(struct dentry *d)
{
	char buf[256];
	char *p;

	if (!d)
		return false;
	p = dentry_path_raw(d, buf, sizeof(buf));
	if (IS_ERR(p))
		return false;
	return str_has_arb(p);
}

static int arbg_sb_mount(const char *dev_name, const struct path *path,
			 const char *type, unsigned long flags, void *data)
{
	if (str_has_arb(dev_name))
		return -EPERM;
	if (path && path->dentry && dentry_is_arb(path->dentry))
		return -EPERM;
	return 0;
}

static int arbg_file_permission(struct file *file, int mask)
{
	if (!file)
		return 0;
	if (mask & MAY_WRITE) {
		if (dentry_is_arb(file->f_path.dentry))
			return -EPERM;
	}
	return 0;
}

static struct security_hook_list arbg_hooks[] = {
	LSM_HOOK_INIT(sb_mount, arbg_sb_mount),
	LSM_HOOK_INIT(file_permission, arbg_file_permission),
};

static int __init arbg_init(void)
{
	pr_info("arb_guard: ARB write-block LSM loaded (update_arb protected)\n");
	security_add_hooks(arbg_hooks, ARRAY_SIZE(arbg_hooks), "arb_guard");
	return 0;
}

DEFINE_LSM(arbg) = {
	.name = "arb_guard",
	.init = arbg_init,
};
