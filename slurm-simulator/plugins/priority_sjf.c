/*
 * priority/sjf: Shortest Job First, the simplest custom scheduling policy.
 *
 * A Slurm priority plugin sets the priority of every job at submission, and the
 * scheduler starts pending jobs in priority order. This one gives the job with
 * the shortest time limit (sbatch -t) the highest priority; jobs with the same
 * time limit keep their submission order. Shortest Job First minimizes the mean
 * wait when time limits are good estimates of run times, at the cost of the long
 * jobs, which wait while shorter ones keep arriving.
 *
 * slurm-simulate builds every plugins/<type>_<name>.c into the simulator as the
 * plugin <type>/<name>; PriorityType=priority/sjf in slurm.conf (the slurm_conf
 * attributes of the cookbook) selects this one. It is a copy of priority/basic
 * (src/plugins/priority/basic in the simulator sources) reduced to what a policy
 * needs: priority_p_set is the policy, the other functions are the rest of the
 * priority plugin interface (src/interfaces/priority.c), with nothing to do.
 */

#include "src/interfaces/priority.h"

/* The plugin loader checks these: the name, the type PriorityType selects, and
 * the Slurm version the plugin is built against. */
const char plugin_name[] = "Priority Shortest Job First plugin";
const char plugin_type[] = "priority/sjf";
const uint32_t plugin_version = SLURM_VERSION_NUMBER;

/* Priority of a job without a time limit, lower than any job with one; priority 0
 * would hold the job, so the lowest is 1. */
#define SJF_UNLIMITED_PRIORITY 1
/* Priority of a job with a time limit of 0 minutes; each minute of time limit
 * takes one off, so any limit under about 1.9 years ranks above an unlimited job. */
#define SJF_TOP_PRIORITY 1000000

int init(void)
{
	debug("%s loaded", plugin_name);
	return SLURM_SUCCESS;
}

int fini(void)
{
	return SLURM_SUCCESS;
}

/* The policy: the priority of a job from its time limit, in minutes. */
extern uint32_t priority_p_set(uint32_t last_prio, job_record_t *job_ptr)
{
	/* A priority an administrator set (scontrol update priority) stays. */
	if (job_ptr->direct_set_prio && (job_ptr->priority > 1))
		return job_ptr->priority;

	uint32_t priority;
	if ((job_ptr->time_limit == NO_VAL) || (job_ptr->time_limit == INFINITE) ||
	    (job_ptr->time_limit >= SJF_TOP_PRIORITY))
		priority = SJF_UNLIMITED_PRIORITY;
	else
		priority = SJF_TOP_PRIORITY - job_ptr->time_limit;

	/* The line priority/multifactor logs, which the toolkit reads into slurmctld_log.csv. */
	info("%s: initial priority for job %u is %u", plugin_type, job_ptr->job_id, priority);
	return priority;
}

/* Priorities do not change after submission: nothing to restore, recompute or
 * account for at restart, reconfiguration, usage update or job end. */
extern uint32_t priority_p_recover(uint32_t prio_boost)
{
	return 0;
}

extern void priority_p_reconfig(bool assoc_clear)
{
	return;
}

extern void priority_p_set_assoc_usage(slurmdb_assoc_rec_t *assoc)
{
	return;
}

extern void priority_p_job_end(job_record_t *job_ptr)
{
	return;
}

/* No fairshare factor and no factors to report (sprio): this policy has a single one. */
extern double priority_p_calc_fs_factor(long double usage_efctv,
					long double shares_norm)
{
	return 0.0;
}

extern List priority_p_get_priority_factors_list(
	priority_factors_request_msg_t *req_msg, uid_t uid)
{
	return list_create(NULL);
}
