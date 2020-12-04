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
        
%         % look for existing metadata
%         path_md = fullfile(path_data, 'metadata');
%         file_md = teFindFile(path_md, '*.metadata.mat');
%         if exist(file_md, 'file')
%             % load if found, then continue to next iteration of the loop
%             % (next session)
%             tmp = load(file_md);
%             md{s} = tmp.metadata;
%             fprintf('Loaded metadata from disk: %s\n', file_md);
%             continue
%         else
%             % instantiate blank object if not found
%             md{s} = teMetadata;
%         end

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
            if isa(ext(ed), 'teExternalData_ScreenRecording') &&...
                    ignoreScreenRecording && ~teVideoHasValidSync(ext(ed))
                warning('Skipped screen recording due to -ignoreScreenRecording flag.')
            else
                if ext(ed).Valid
                    [md{s}, tracker{s}] = tepInspect_externalData(ext(ed), md{s}, tracker{s});
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
        
        % hash tracker and external data, to detect changes in future
        md{s}.Hash = lm_hashVariables(tracker{s}, ext);
        
        % write metadata to session folder
        path_md = fullfile(path_data, 'metadata');
        tryToMakePath(path_md);
        file_md = fullfile(path_md, sprintf('%s.metadata.mat', md{s}.GUID));
        metadata = md{s};
        saveMetadata(file_md, metadata)
        
        saveTracker(md{s}.Paths('tracker'), tracker{s});
        
    end
    
    % if only one session passed, remove the metadata and summary from
    % their cell arrays and return as scalars
    if numSes == 1
        md = md{1};
        smry = smry{1};
    end

end

function saveMetadata(file_md, metadata)
    save(file_md, 'metadata')
end

function saveTracker(file_tracker, tracker)
    file_backup = strrep(file_tracker, '.mat',...
        '.mat.bak.tepInspect');
    movefile(file_tracker, file_backup);
    save(file_tracker, 'tracker');
end