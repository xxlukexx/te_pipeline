function md = tepInspect_screenrecording(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_screenrecording.success = false;
        md.tepInspect_screenrecording.outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    % determine whether the video has been synced
    [hasSync, validSyncStruct] = teVideoHasValidSync(ext);
    
    % optionally sync. May take this out as it's quite time consuming when
    % just inspecting data. OTOH it's a good way of forcing files to be
    % synced, and only has to be done once. We only do this is the sync
    % struct is invalid. A valid sync sruct without sync is the product of
    % missing markers in the video, so we assume nothing has changed and
    % don't try to sync again
    if ~hasSync && ~validSyncStruct
        try
            ext.ImportSync(teSyncVideo(ext.Paths('screenrecording')));
        catch ERR_sync
            warning('Error syncing video:\n\n%s', ERR_sync.message)
        end
        hasSync = teVideoHasValidSync(ext);
    end
    
    % try to extract times from sync
    if hasSync
        md.Checks.screenrecording_t1 = ext.Sync.timestamps(1);
        md.Checks.screenrecording_t2 = ext.Sync.timestamps(end);
        
        % check for early datasets with PTB GetSecs clock
        if md.Checks.screenrecording_t1 < 1e6
            md.Checks.screenrecording_timestamps_old = true;
        end
    end

    md.tepInspect_screenrecording.success = true;
    md.tepInspect_screenrecording.outcome = 'success';

end