function md = tepInspect_screenrecording(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_screenrecording_success = false;
        md.tepInspect_screenrecording_outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    % determine whether the video has been synced
    hasSync = teVideoHasValidSync(ext);
    
    % optionally sync. May take this out as it's quite time consuming when
    % just inspecting data. OTOH it's a good way of forcing files to be
    % synced, and only has to be done once
    if ~hasSync
        ext.ImportSync(teSyncVideo(ext.Paths('screenrecording')));
    end
    
    % try to extract times from sync
    if ~isempty(ext.Sync)
        md.Checks.screenrecording_t1 = ext.Sync.timestamps(1);
        md.Checks.screenrecording_t2 = ext.Sync.timestamps(end);
    end

    md.tepInspect_screenrecording_success = true;
    md.tepInspect_screenrecording_outcome = 'success';

end