function [vars, hasDups, idx_dup, groupedDups] =...
    tepDiscoverSessions(paths, varargin)
% Searches a path for loadable Task Engine sessions. Checks whether any are
% duplicates by looking for identical metadata (e.g. ID, age, site etc.) in
% the tracker

% check input args

    % check path(s)
    if ~exist('paths', 'var') || isempty(paths) ||...
            (~ischar(paths) && ~iscellstr(paths))
        error('Must provide a path (char) or paths (cellstr) to search.')
    end
    
    % if scalar path, put into cell array
    if ischar(paths)
        paths = {paths};
    end
    
% search

    path_ses = {};
    trackers = {};
    vars = {};

    numPaths = length(paths);
    for p = 1:numPaths
        
        [tmp_path_ses, tmp_trackers, tmp_vars] = teRecFindSessions(paths{p});
        path_ses = [path_ses; tmp_path_ses];
        trackers = [trackers; tmp_trackers];
        vars = [vars; tmp_vars];
        
    end
    
    % append path to vars table
    vars.SessionPath = path_ses;
    
% find duplicates

    % find vars to use to make signature. These will be all dynamic
    % properties added to the tracker, but not things like session duration
    % which will differ
    unwantedVars =...
        {'GUID', 'SessionStart', 'Duration', 'logIdx', 'SessionPath'};
    wantedVars = setdiff(vars.Properties.VariableNames, unwantedVars);
    
    % make signatures from wanted variables
    [sig, sig_u, sig_i, sig_s, numSig] = makeSig(vars, wantedVars);
    
    % count dups 
    hasDups = ~isequal(sig, size(sig_u));
    if hasDups
        
        tb = tabulate(sig);
        dupTabIdx = cell2mat(tb(:, 2)) > 1;
        tb = tb(dupTabIdx, :);
        idx_dup = find(...
            cellfun(@(x) ~isempty(find(strcmpi(tb(:, 1), x), 1)),...
            sig));
        groupedDups = cellfun(@(x) find(strcmpi(x, sig)),...
            tb(:, 1), 'uniform', false);
        
    end

    % add duplicate info to table
    vars.IsDuplicate = false(size(vars, 1), 1);
    vars.IsDuplicate(idx_dup) = true;

end