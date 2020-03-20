function md = tepInspect_session(tracker, md)

    teEcho('Inspecting session with GUID: %s...\n', tracker.GUID);
    
    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_session.success = false;
        md.tepInspect_session.outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    if ~isa(tracker, 'teTracker')
        md.tepInspect_session.success= false;
        md.tepInspect_session.outcome = 'passed variable was not teTracker instance';
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
    
    % check log
    md.Log.present = isprop(tracker, 'Log') && ~isempty(tracker.Log);
    if md.Log.present
        
        % get log indices. Do this by convertin the log to a table a recording
        % earliest and latest row indices (which will correspond to log
        % indices)
        tab = teLogExtract(tracker.Log);
        md.Log.log_t1 = min(tab.timestamp);
        md.Log.log_t2 = max(tab.timestamp);

        % check for early datasets with PTB GetSecs clock
        if md.Log.log_t1 < 1e6
            md.Log.log_timestamps_old = true;
        end
        
    end

    md.tepInspect_session.success = true;
    md.tepInspect_session.outcome = 'success';

end