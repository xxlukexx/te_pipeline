function md = tepInspect_session(tracker, md)

    teEcho('Inspecting session with GUID: %s...\n', tracker.GUID);
    
    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.Checks.tepInspect_session_success = false;
        md.Checks.tepInspect_session_outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    if ~isa(tracker, 'teTracker')
        md.Checks.tepInspect_session_success= false;
        md.Checks.tepInspect_session_.outcome = 'passed variable was not teTracker instance';
        return
    end
    
    % get general metadata
    md.GUID = tracker.GUID;
    md.sessionstarttime = tracker.SessionStartTime;
    md.sessionendtime = tracker.SessionEndTime;
    md.resuming = tracker.Resuming;
    
    % get variables
    [vars, vals] = tracker.GetVariables;
    numVars = length(vars);
    for v = 1:numVars
        md.(vars{v}) = vals{v};
    end
    
    % get log indices. Do this by convertin the log to a table a recording
    % earliest and latest row indices (which will correspond to log
    % indices)
    tab = teLogExtract(tracker.Log);
    md.Checks.log_t1 = min(tab.timestamp);
    md.Checks.log_t2 = max(tab.timestamp);
    
    md.Checks.tepInspect_session_success = true;
    md.Checks.tepInspect_session_outcome = 'success';

end