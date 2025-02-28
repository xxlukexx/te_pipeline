function md = tepInspect(path_data, varargin)

    % find te sessions
    [isSes, ~, ~, tmp_tracker] = teIsSession(path_data);
    if isSes
        path_ses = {path_data};
        tracker = {tmp_tracker};
    else
        [path_ses, tracker] = teRecFindSessions(path_data);
    end
    numSes = length(path_ses);
    
    clear j
    j = tepJobManager;
    cellfun(@(x, y) j.AddJob(@tepInspect_oneDataset, 3, [], x, 'tracker', y, 'rebuildmetadata', true), path_ses, tracker);
    j.RunJobs
    
    % retrieve metadata from job manager
    md = cellfun(@(x) x.result{3}, j.Jobs.Items, 'UniformOutput', false);
    
%     % loop through and inspect
%     md = cell(numSes, 1);
%     smry = cell(numSes, 1);
%     parfor s = 1:numSes
%         
% %         % look for existing metadata. Can be avoided by setting the
% %         % -rebuildMetadata flag, in which case md will be created
% %         % afresh. If no existing metadata is found, then a blank teMetadata
% %         % is returned. If valid md is found, skip the rest of the loop
% %         % execution and move to the next dataset (since everything after
% %         % this is concerned with creating the metadata from the session). 
% %         if loadExistingMetadata
% %             [suc_loadExistingMetadata, md{s}] =...
% %                 tepInspect_tryToLoadExistingMetadata(path_data);
% %         else
% %             md{s} = teMetadata;
% %             suc_loadExistingMetadata = false;
% %         end
% %         if suc_loadExistingMetadata, continue, end
% %              
% %         % add tracker path to metadata
% %         md{s}.LocalSessionFolder = path_ses{s};
% %         parts = strsplit(path_ses{s}, filesep);
% %         md{s}.Paths('tracker') = teFindFile(path_ses{s}, 'tracker*.mat');
% %         
% %         % inspect session
% %         md{s} = tepInspect_session(tracker{s}, md{s});
% %         
% %         % discover external data for this session
% %         [ext, md{s}] = teDiscoverExternalData(path_ses{s}, md{s});
% %         
% %         % loop through and inspect external data
% %         [md{s}, tracker{s}] = doInspect(ext, md{s}, tracker{s}, [], varargin{:});
% %         
% %         % in case new external data (e.g. enobio -> fieldtrip) has been
% %         % produced in the previous step, search for it
% %         ext2 = teDiscoverExternalData(path_ses{s}, md{s});
% %         [newKeys, idx_newKeys] = setdiff(ext2.Keys, ext.Keys);
% %         if ~isempty(newKeys)
% %             [md{s}, tracker{s}] = doInspect(ext2, md{s}, tracker{s}, idx_newKeys, varargin{:});
% %         end
% %         ext = teDiscoverExternalData(path_ses{s}, md{s});
% %         
% %         % inspect tasks
% %         md{s} = tepInspect_tasks(tracker{s}, md{s});
% % 
% %         % create summary by taking only those metadata fileds that contain
% %         % 'tepInspect_*_outcome'. Put these in a smaller struct that serves
% %         % as the summary of all inspections
% %         mds = struct(md{s});
% %         fn = fieldnames(mds);
% %         idx = contains(fn, 'tepInspect') & contains(fn, '_outcome');
% %         smry{s} = struct;
% %         for i = 1:length(fn)
% %             if idx(i)
% %                 smry{s}.(fn{i}) = mds.(fn{i});
% %             end
% %         end
% %         
% %         % save updated tracker
% %         saveTracker(md{s}.Paths('tracker'), tracker{s});
% %         
% %         % hash tracker and external data, to detect changes in future
% %         md{s}.Hash = lm_hashClass(tracker{s}, ext);
% % %         md{s}.Hash = lm_hashVariables(tracker{s}, ext);
% %         
% %         % write metadata to session folder
% %         path_md = fullfile(path_ses{s}, 'metadata');
% %         tryToMakePath(path_md);
% %         file_md = fullfile(path_md, sprintf('%s.metadata.mat', md{s}.GUID));
% %         metadata = md{s};
% %         saveMetadata(file_md, metadata)
%         
%     end


    
    % if only one session passed, remove the metadata and summary from
    % their cell arrays and return as scalars
    if numSes == 1
        md = md{1};
%         smry = smry{1};
    end

end




    
    
    
    
