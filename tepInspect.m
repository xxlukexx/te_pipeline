function [md, smry] = tepInspect(path_data, varargin)

    % support cell arrays of paths
    if iscellstr(path_data)
        [md, smry] = cellfun(@(x) tepInspect(x, varargin{:}), path_data,...
            'UniformOutput', false);
        return
    end

    ignoreScreenRecording = ~isempty(varargin) &&...
        ismember(varargin, '-ignoreScreenRecording');

    % find te sessions
    [path_ses, tracker] = teRecFindSessions(path_data);
    numSes = length(path_ses);
    
    % loop through and inspect
    md = cell(numSes, 1);
    smry = cell(numSes, 1);
    for s = 1:numSes
        
        md{s} = teMetadata;
        
        % add tracker path to metadata
        md{s}.LocalSessionFolder = path_ses{s};
        parts = strsplit(path_ses{s}, filesep);
        md{s}.LocalTrackerFile = [filesep, fullfile(parts{1:end - 1})];
        md{s}.Paths('tracker') = teFindFile(path_ses{s}, 'tracker*.mat');
        
        % inspect session
        md{s} = tepInspect_session(tracker{s}, md{s});
        
        % discover external data for this session
        [ext, md{s}] = teDiscoverExternalData(path_ses{s}, md{s});
        
        % loop through and inspect external data
        for ed = 1:ext.Count
            if isa(ext(ed), 'teExternalData_ScreenRecording') && ignoreScreenRecording
                warning('Skipped screen recording due to -ignoreScreenRecording flag.')
            else
                if ext(ed).Valid
                    md{s} = tepInspect_externalData(ext(ed), md{s});
                end
            end
        end
        
        % create summary by taking only those metadata fileds that contain
        % 'tepInspect_*_outcome'. Put these in a smaller struct that serves
        % as the summary of all inspections
        mds = struct(md{s});
        fn = fieldnames(mds);
        idx = contains(fn, 'tepInspect') & contains(fn, '_outcome');
        smry{s} = struct;
        for i = 1:length(fn)
            if idx(i)
                smry{s}.(fn{i}) = mds.(fn{i});
            end
        end
        
    end
    
    % if only one session passed, remove the metadata and summary from
    % their cell arrays and return as scalars
    if numSes == 1
        md = md{1};
        smry = smry{1};
    end

end