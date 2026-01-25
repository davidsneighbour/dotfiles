## Data export is failing

Sometimes the file rights on the NFS are borked. In that case create the export symlink via `dotbot hal2025`, then delete the folder on the external drive, then run `backup` and the folder is recreated with proper file rights. Doing that manually for some reason fails. 
