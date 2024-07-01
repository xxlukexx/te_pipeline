function [suc, oc, md] = tepInspect_oneDataset(path_ses, varargin)

    suc = false;
    oc = 'unknown error';
    md = [];
    
        parser = inputParser;
        parser.addParameter('syncmarker', 'SYNC', @ischar);
        parser.addParameter('tracker', [], @(x) isa(x, 'teTracker')); 
        parser.addParameter('rebuildmetadata', false, @islogical); 
        parser.addParameter('ignorescreenrecording', true, @islogical);
        parser.parse(varargin{:});
        syncMarker = parser.Results.syncmarker;
        tracker = parser.Results.tracker;
        loadExistingMetadata = ~parser.Results.rebuildmetadata;
        ignoreScreenRecording = parser.Results.ignorescreenrecording;
                
    
%     % handle input args
%     [tracker, loadExistingMetadata, ignoreScreenRecording, syncMarker,...
%         varargin] =...
%         handleInputArgs(path_ses, varargin{:});
    
    % look for existing metadata. Can be avoided by setting the
    % -rebuildMetadata flag, in which case md will be created
    % afresh. If no existing metadata is found, then a blank teMetadata
    % is returned. If valid md is found, skip the rest of the loop
    % execution and move to the next dataset (since everything after
    % this is concerned with creating the metadata from the session). 
    
        if loadExistingMetadata
            [suc_loadExistingMetadata, md] =...
                tryToLoadExistingMetadata(path_ses);
            md.metaDataSource = 'disk';
        else
            md = teMetadata;
            suc_loadExistingMetadata = false;
            md.metaDataSource = 'built';
        end
        if suc_loadExistingMetadata
            suc = true;
            oc = '';
            return
        end

    % if no tracker is passed, attempt to find it's location within the
    % session folder, and load it. If a tracker is passed, we still need
    % it's location, so just look for the file but don't load it
    
        if ~exist('tracker', 'var') || isempty(tracker)

            % try to find and load the tracker
            [suc_loadTracker, oc_loadTracker, tracker, file_tracker] =...
                tryToLoadTracker(path_ses);
            if ~suc_loadTracker
                oc = oc_loadTracker;
                return
            end

        else

            % just try to locate the tracker but don't load it (one was already
            % passed to this function)
            [suc_findTracker, oc_findTracker, file_tracker] =...
                tryToFindTracker(path_ses);
            if ~suc_findTracker
                oc = oc_findTracker;
            end

        end

    % store the path to the tracker in the metadata
    md.Paths('tracker') = file_tracker;

    % add tracker path to metadata
    md.LocalSessionFolder = path_ses;

    % inspect session
    md = tepInspect_session(tracker, md);

    % discover external data for this session
    [ext, md] = teDiscoverExternalData(path_ses, md);

    % loop through and inspect external data
    [md, tracker] = inspectAllExternalData(ext, md, tracker, [], varargin{:});

    % in case new external data (e.g. enobio -> fieldtrip) has been
    % produced in the previous step, search for it
    ext2 = teDiscoverExternalData(path_ses, md);
    [newKeys, idx_newKeys] = setdiff(ext2.Keys, ext.Keys);
    if ~isempty(newKeys)
        [md, tracker] = inspectAllExternalData(ext2, md, tracker, idx_newKeys, varargin{:});
    end
    ext = teDiscoverExternalData(path_ses, md);

    % inspect tasks
    md = tepInspect_tasks(tracker, md);

    % create summary by taking only those metadata fileds that contain
    % 'tepInspect_*_outcome'. Put these in a smaller struct that serves
    % as the summary of all inspections
    mds = struct(md);
    fn = fieldnames(mds);
    idx = contains(fn, 'tepInspect') & contains(fn, '_outcome');
    smry = struct;
    for i = 1:length(fn)
        if idx(i)
            smry.(fn{i}) = mds.(fn{i});
        end
    end

    % save updated tracker
    saveTracker(md.Paths('tracker'), tracker);

    % hash tracker and external data, to detect changes in future
    md.Hash = lm_hashClass(tracker, ext);

    % write metadata to session folder
    path_md = fullfile(path_ses, 'metadata');
    tryToMakePath(path_md);
    file_md = fullfile(path_md, sprintf('%s.metadata.mat', md.GUID));
    metadata = md;
    saveMetadata(file_md, metadata)
    
    suc = true;
    oc = '';

end

function [tracker, loadExistingMetadata, ignoreScreenRecording,...
    syncMarker, varargin] =...
    handleInputArgs(path_ses, varargin)

    % check session path exists
    if ~exist(path_ses, 'dir')
        oc = sprintf('Session path not found: %s', path_ses);
        return
    end

%     % parse optional switches
% 
%         % re-build or load existing metadata
%         idx_rebuild = strcmpi(varargin, '-rebuildmetadata');
%         loadExistingMetadata = ~any(idx_rebuild);
%         varargin(idx_rebuild) = [];
% 
%         % ignore screen recording
%         idx_ignoreSC = strcmpi(varargin, '-ignorescreenrecording');
%         ignoreScreenRecording = ~isempty(idx_ignoreSC);
%         varargin(idx_ignoreSC) = [];

    % use Matlab input parser to parse remaining input args

        parser = inputParser;
        parser.addParameter('syncmarker', 'SYNC', @ischar);
        parser.addParameter('tracker', [], @(x) isa(x, 'teTracker')); 
        parser.addParameter('rebuildmetadata', false, @islogical); 
        parser.addParameter('ignorescreenrecording', true, @islogical);
        parser.parse(varargin{:});
        syncMarker = parser.Results.syncmarker;
        tracker = parser.Results.tracker;
        loadExistingMetadata = ~parser.Results.rebuildmetadata;
        ignoreScreenRecording = parser.Results.ignorescreenrecording;
            
end

function [suc, oc, tracker, file_tracker] = tryToLoadTracker(path_ses)
% Try to find tracker files within a session folder. If one is found, load
% and return it. If a problem occurs at any stage, report it via [suc, oc]

    suc = false;
    oc = 'unknown error';
    tracker = [];
    file_tracker = [];
    
    % code to find the location of a tracker file within a session folder
    % is elsewhere, so that it can be called indepdently 
    [suc_findTracker, oc_findTracker, file_tracker] =...
        tryToFindTracker(path_ses);
    if ~suc_findTracker
        oc = oc_findTracker;
        return
    end
    
    % attempt to load
    try
        tmp = load(file_tracker);
        if isfield(tmp, 'tracker')
           tracker = tmp.tracker;
        else
            oc = sprintf('Invalid tracker format in %s', file_tracker);
            return
        end
    catch ERR
        oc = sprintf('Error when attempting to load tracker %s: %s',...
            file_tracker, ERR.message);
        return
    end

    % check that the loaded object is the correct teTracker class
    if ~isa(tracker, 'teTracker')
        oc = sprintf('Tracker variable in file %s is not a teTracker object',...
            file_tracker);
        return
    else
        suc = true; 
        oc = '';
    end
    
end
            
function [suc, oc, file_tracker] = tryToFindTracker(path_ses)
% Try to find the location of a tracker file within a session folder, and
% return it if successful. 

    suc = false;
    oc = 'unknown error';
    
    file_tracker = teFindFile(path_ses, 'tracker*.mat');
    if isempty(file_tracker)
        oc = sprintf('No tracker file found in %s', path_ses);
        return
    elseif iscell(file_tracker) && length(file_tracker) > 1
        oc = sprintf('Multiple (%d) tracker files found in %s',...
            length(file_tracker), path_ses);
        return
    end

    suc = true;
    oc = '';

end
        
function [suc, md] = tryToLoadExistingMetadata(path_ses)
    suc = false;
    path_md = fullfile(path_ses, 'metadata');
    file_md = teFindFile(path_md, '*.metadata.mat');
    if exist(file_md, 'file')
        % load if found, then continue to next iteration of the loop
        % (next session)
        tmp = load(file_md);
        md = tmp.metadata;
        fprintf('Loaded metadata from disk: %s\n', file_md);
        suc = true;
    else
        % instantiate blank object if not found
        md = teMetadata;
        suc = false;
    end
end

function [md, tracker] = inspectAllExternalData(ext, md, tracker, idx, varargin)
    
    ignoreScreenRecording = true;
    warning('Currently forcing ignore of screen recording.')
    for ed = 1:ext.Count
        % optionally skip an element if it doesn't exist in idx. If idx is
        % empty, don't skip. 
        if ~isempty(idx) && ~ismember(ed, idx)
            continue
        end
        if isa(ext(ed), 'teExternalData_ScreenRecording') &&...
                ignoreScreenRecording && ~teVideoHasValidSync(ext(ed))
            warning('Skipped screen recording due to -ignoreScreenRecording flag.')
        else
            if ext(ed).Valid
                [md, tracker] =...
                    tepInspect_externalData(ext(ed), md, tracker, varargin{:});
            end
        end
    end
        
end

function saveMetadata(file_md, metadata)
    fprintf('Saving metadata with hash: %s to: %s\n', metadata.Hash, file_md)
    save(file_md, 'metadata')
end

function saveTracker(file_tracker, tracker)
    file_backup = strrep(file_tracker, '.mat',...
        '.mat.bak.tepInspect');
    movefile(file_tracker, file_backup);
    save(file_tracker, 'tracker');
end