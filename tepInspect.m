function md = tepInspect(path_data)

    % find te sessions
    [path_ses, tracker] = teRecFindSessions(path_data);
    numSes = length(path_ses);
    
    % loop through and inspect
    md = cell(numSes, 1);
    for s = 1:numSes
        
        md{s} = teMetadata;
        
        % add tracker path to metadata
        md{s}.Paths('session_folder') = path_ses{s};
        parts = strsplit(path_ses{s}, filesep);
        md{s}.Paths('subject_folder') = [filesep, fullfile(parts{1:end - 1})];
        md{s}.Paths('tracker') = teFindFile(path_ses{s}, 'tracker*');
        
        % inspect session
        md{s} = tepInspect_session(tracker{s}, md{s});
        
        % discover external data for this session
        ext = teDiscoverExternalData(path_ses{s});
        
        % loop through and inspect external data
        for ed = 1:ext.Count
            md{s} = tepInspect_externalData(ext(ed), md{s});
        end
                
    end


end