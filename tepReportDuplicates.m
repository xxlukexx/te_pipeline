function tepReportDuplicates(vars, idx_dup, grp_dup)
% Reports details of duplicate sessions (found with tepDiscoverSessions) to
% the command window. 

    teLine
    teEcho('Duplicated sessions were found:\n\n');
    
    numGrp = length(grp_dup);
    for g = 1:numGrp
        
        teEcho('%d. %d sessions are duplicates:\n', g, length(grp_dup{g}));
        disp(vars(grp_dup{g}, :))
        
    end










end