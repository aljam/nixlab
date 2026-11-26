diff --git a/modules/features/restic-backup.nix b/modules/features/restic-backup.nix
index 0000000..0000000 100644
--- a/modules/features/restic-backup.nix
+++ b/modules/features/restic-backup.nix
@@ -1,3 +1,3 @@
-nixlab_restic_${prefix}_last_success_timestamp_seconds{job="${name}"} "$success_timestamp"
+nixlab_restic_${prefix}_last_success_timestamp_seconds{job="${name}"} $success_timestamp
 
-nixlab_restic_${prefix}_last_result{job="${name}"} "$result"
+nixlab_restic_${prefix}_last_result{job="${name}"} $result
 
-nixlab_restic_${prefix}_duration_seconds{job="${name}"} "$duration"
+nixlab_restic_${prefix}_duration_seconds{job="${name}"} $duration
