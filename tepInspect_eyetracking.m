function md = tepInspect_eyetracking(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_eyetracking.success = false;
        md.tepInspect_eyetracking.outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    md.Checks.eyetracking_t1 = ext.Buffer(1, 1);
    md.Checks.eyetracking_t2 = ext.Buffer(end, 1);
    
    % check for early datasets with PTB GetSecs clock
    if md.Checks.eyetracking_t1 < 1e6
        md.Checks.eyetracking_timestamps_old = true;
    end
        
    md.tepInspect_eyetracking.success = true;
    md.tepInspect_eyetracking.outcome = 'success';

end