function md = tepInspect_eyetracking(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.Checks.tepInspect_eyetracking_success = false;
        md.Checks.tepInspect_eyetracking_outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    md.Checks.eyetracking_t1 = ext.Buffer(1, 1);
    md.Checks.eyetracking_t2 = ext.Buffer(end, 1);

    md.Checks.tepInspect_eyetracking_success = true;
    md.Checks.tepInspect_eyetracking_outcome = 'success';

end