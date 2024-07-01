classdef tepAnalysisServer < tepAnalysisDatabase
    
    properties 
        Port = 3000
    end
    
    properties (Dependent, SetAccess = private)
        Metadata        
        ClientDetails
    end
    
    properties (SetAccess = private)
    end
    
    properties (Access = private)
        prSocket 
        prConns = []
        prNetTimer
        prSaveTimer
        prMetadataDirty = false
        prIsShutdown = false
        prClientIP = {}
        prClientPort = []
        prClientUser = {}
        prClientBlocked = []
        prAccessList
    end
    
    properties (Constant)
        CONST_timerRate = .05
        CONST_path_accessList = '/users/luke/desktop/access.mat';
    end
    
    methods
        
        function obj = tepAnalysisServer
            
            % check for pnet 
            if isempty(which('pnet'))
                error('This class requires the ''pnet'' library.')
            end
            
            % load access list
            obj.loadAccessList
            
            % create a TCP/IP socket
            obj.prSocket = pnet('tcpsocket', obj.Port);
            
            % set up timer
            obj.prNetTimer = timer(...
                'Period', obj.CONST_timerRate,...
                'ExecutionMode', 'fixedRate',...
                'TimerFcn', @obj.TimerHandleNetwork,...
                'ErrorFcn', @obj.TimerHandleError,...
                'BusyMode', 'drop');
            start(obj.prNetTimer)
            
            obj.prSaveTimer = timer(...
                'Period', 10,...
                'ExecutionMode', 'fixedRate',...
                'TimerFcn', @obj.saveMetadataToFilesystem,...
                'BusyMode', 'drop');
            start(obj.prSaveTimer)
        end
        
        function ShutDown(obj)
            stop(obj.prNetTimer)
            delete(obj.prNetTimer)
            pnet('closeall')   
            obj.prIsShutdown = true;
        end
        
        function delete(obj)
            if ~obj.prIsShutdown, obj.ShutDown, end
        end
        
        function TimerHandleNetwork(obj, varargin)
            try
                obj.HandleNetwork
            catch ERR
                disp(getReport(ERR, 'extended', 'hyperlinks', 'on'))
                rethrow(ERR)
            end
        end
        
        function TimerHandleError(~, varargin)
            error(varargin{2}.Data.message)
        end

        function HandleNetwork(obj, ~, ~)
        % handles all network communication. Called by a timer at a certain
        % interval. Checks for connection requests, and for database
        % requests from connected clients. All requests are responded to
        % immediately if possible
                
            % if not connected to database, do not handle network
            if ~obj.prConnectedToDatabase, return, end
                       
            % handle connection requests
            obj.HandleNewNetworkConnections
            
            % handle protocol messages for all connections
            obj.HandleNetworkProtocol
            
        end
        
        function HandleNetworkProtocol(obj)
        % loops through all connections and checks for protocol requests,
        % then handles these
        
            numConnections = length(obj.prConns);
            for c = 1:numConnections 
                
                % check if this client is blocked
                if obj.prClientBlocked(c), continue, end
                                
                % check buffer
                res = pnet(obj.prConns(c), 'readline', 'noblock');
                
%                 if isempty(res)
%                     fprintf('No data (empty) from connection %d\n', c);
%                 elseif strcmpi(res, '')
%                     fprintf('No data (empty string) from connection %d\n', c);
%                 elseif isequal(res, -1)
%                     fprintf('Error (res was -1) checking connection %d\n', c)
%                 else
%                     fprintf('Data from %d was: %s\n', c, res)
%                 end
                
                if isempty(res) || isequal(res, -1)
                    % no messages from this connection, move on
                    continue
                end
                    
                % take first word of protocol message - this is the
                % command
                parts = strsplit(res, ' ');
                cmd = parts{1};

                % data is any subsequent words
                if length(parts) > 1
                    data = parts(2:end);
                else
                    data = [];
                end
                
                % send ready
                obj.netSendReady(obj.prConns(c))

                switch cmd

                    case 'GET'
                        
                        obj.AddLog('Executing command [%s] for client %s\n',...
                            res, obj.ClientDetails{c});
                        err = obj.NetGET(obj.prConns(c), data);
                        

                        
                    case 'INGEST'
                        
                        obj.NetIngest(obj.prConns(c));
                        
                    case 'UPDATE'
                        
                        obj.NetUpdate(obj.prConns(c));
                        
                    case 'USER'
                        
                        obj.prClientUser{c} = data{1};
                        
                    otherwise
                        
                        % unrecognised command
                        obj.NetError(obj.prConns(c),...
                            sprintf('Unrecognised protocol command %s.', cmd))
                        
                end
                
            end
            
        end
          
        function HandleNewNetworkConnections(obj)
        % polls for new TCP/IP connections from clients, and initiates them
            
            % check for new connections
            res = pnet(obj.prSocket, 'tcplisten', 'noblock');
            
            if res ~= -1
                
                % load latest access list
                obj.loadAccessList
            
                % store connection handle in array
                obj.prConns(end + 1) = res;   
                
                % set read timeout to default
                pnet(obj.prConns(end), 'setreadtimeout',...
                    obj.CONST_ReadTimeout)
                
                % get IP and port of client
                [ip_client, port_client] = pnet(obj.prConns(end), 'gethost');
                
                % convert IP vector to string
                ip_client = sprintf('%d.', ip_client);
                ip_client(end) = [];
                
                % store
                obj.prClientIP{res} = ip_client;
                obj.prClientPort(res) = port_client;
                obj.prClientUser{res} = 'unknown';
                
                % request MAC address
                obj.netSendReady(res);
                mac_remote = obj.NetReceiveVar(res);
                
                % we want mac address elements to be separated by
                % dashes, not colons 
                mac_remote = upper(strrep(mac_remote, ':', '-'));
                
                % check MAC address against access list
                if ~ismember(mac_remote, obj.prAccessList)

                    obj.NetError(res, 'Access denied.');
                    obj.AddLog('Client %s had MAC address %s, access denied\n',...
                        obj.prClientUser{res}, mac_remote);
                    obj.prClientBlocked(res) = true;
                    return
                end
                obj.prClientBlocked(res) = false;
                obj.netSendReady(res);
                
                obj.AddLog('Client connected on %s\n', obj.ClientDetails{res});
                
            end
            
        end
        
        function err = NetIngest(obj, conn)
        % receives newly ingested metadata from the client, validates it,
        % and saves it to disk. If the guid already exists in the database
        % then this is an error
            
            err = true;
            
            % receive variable
            md_ingest = obj.NetReceiveVar(conn);
            obj.AddLog('Received metadata chunk [%s] from %s\n',...
                md_ingest.GUID, obj.ClientDetails{conn});
            
            % validate metadata setting isUpdate flag to false
            [valid, err] = obj.validateMetadata(md_ingest, false);
            
            % send validation response to client
            obj.NetSendVar(conn, valid);
            
            % if error, send error message
            if ~valid
                obj.NetSendVar(conn, err);
                return
            end
            
            % append to in-memory copy of metadata
            obj.md{end + 1} = md_ingest;
            
%             % save
%             obj.saveMetadataToFilesystem
            obj.prMetadataDirty = true;
            
            err = false;
            
        end
        
        function err = NetUpdate(obj, conn)
        % receives an updated metadata chunk from a client, adds it to the
        % in-memory metadata, and saves the metadata to disk. If the guid
        % does not exist, this is an error (and suggests that NetIngest
        % should have been used instead)
        
            err = true;
            
            % receive variable
            md_update = obj.NetReceiveVar(conn);
               
            % validate metadata, setting isUpdate flag to true 
            [valid, err] = obj.validateMetadata(md_update, true);
            
            % send validation response to client
            obj.NetSendVar(conn, valid);
            
            % if error, send error message
            if ~valid
                obj.NetSendVar(conn, err);
                return
            end
            
            obj.AddLog('Received metadata chunk [%s] from %s\n',...
                md_update.GUID, obj.ClientDetails{conn});
            
            % remove uitable
            md_update.clearTable;
            
            % get index of current metadata in database
            [~, idx] = teLogFilter(obj.LogArray, 'GUID', md_update.GUID);
            obj.md{idx} = md_update;
            
%             % save
%             obj.saveMetadataToFilesystem
            obj.prMetadataDirty = true;
            
            err = false;
            
        end
        
        function ConnectToDatabase(obj, path_db)
            
            % check input args
            if ~exist('path_db', 'var') || isempty(path_db)
                error('Must supply a path to the database.')
            end            
            
            obj.validateDatabasePath(path_db);
            
            % attempt to load metadata
            try
                tmp = load(obj.Path_Metadata);
                % convert from object array to cell array of objects if
                % required
                if isa(tmp.md, 'teMetadata')
                    tmp.md = obj.convertMetadataObjectArrayToCellArray(tmp.md);
                end
            catch ERR_loadMetadata
                error('Error attempting to load metadata file:\n\n%s\n\n%s',...
                    obj.Path_Metadata, ERR_loadMetadata.message)
            end

            % inspect metadata for validity
            if ~isfield(tmp, 'md') && iscell(tmp.md)
                error('Invalid database structure.')
            end

            % update in-memory copy
            obj.md = tmp.md;    

            % extract database name from its path
            parts = strsplit(path_db, filesep);
            obj.prName = parts{end};
            
            % look for config 
            file_config = fullfile(path_db, 'config.mat');
            if exist(file_config, 'file')
                load(file_config);
                if isfield(config, 'path_backup')
                    obj.prPath_Backup = config.path_backup;
                end
            end
            
            obj.prConnectedToDatabase = true;
            
        end   
        
        function res = VerifyDatabase(obj)
        % inspect each item of metadata for all records, then verify that
        % each file referred to in the Paths collection exists. Returns
        % res, a table of results
            
            md = obj.Metadata;
            numMetadata = length(md);
            idx_val = cell(numMetadata, 1);
            res = table;
            for m = 1:numMetadata
                
                fprintf('Verifying metadata [%s], %d of %d...\n',...
                    md{m}.GUID, m, numMetadata);
                
                numPaths = md{m}.Paths.Count;
                idx_val{m} = false(numPaths, 1);
                tmp = table;
                tmp.guid = repmat({md{m}.GUID}, numPaths, 1);
                tmp.idx_metadata = repmat(m, numPaths, 1);
                tmp.idx_path = [1:numPaths]';
                for p = 1:numPaths
                    
                    % get locator path, form absolute path
                    path_loc = md{m}.Paths(p);
                    tmp.path{p} = md{m}.Paths.Keys{p};
                    tmp.path_fs{p} = fullfile(obj.Path_Data, path_loc);
                    
                    % store
                    tmp.valid(p) = exist(tmp.path_fs{p}, 'file') == 2;
                    
                end
                
                if ~isempty(tmp)
                    res = [res; tmp];
                end
                
            end
            
        end
        
        function res = RemoveOrphanedMetadataChunks(obj)
        % first verifies that each path in each metadata chunk is valid, by
        % calling the VerifyDatabase method. Orphaned chunks are those with
        % a path entry in their metadata, but with missing files in the
        % file system. These orphaned chunks are then removed from the
        % metadata array. 
            
            % verify
            res = obj.VerifyDatabase;
            
            % filter for invalid
            res = res(~res.valid, :);
            if isempty(res)
                fprintf('All metadata is valid.\n');
                return
            end
            
            % back up metadata
            path_src = obj.Path_Metadata;
            file_bak = sprintf(...
                'metadata_backup_RemoveOrphanedMetadataChunks_%s.mat',...
                datestr(now, 30));
            path_bak = fullfile(obj.Path_Database, file_bak);
            copyfile(path_src, path_bak);    
            
            % remove
            for m = 1:size(res, 1)
                
                md = obj.Metadata{res.idx_metadata(m)};
                md.Paths.RemoveItem(res.path{m});
                obj.AddLog(sprintf(...
                    'Removed orphaned path [%s] for metadata [%s]\n',...
                    res.path{m}, res.guid{m}));
            
            end
            
            obj.prMetadataDirty = true;
            
        end
        
        function ClearAllMetadata(obj)
        % this deletes all metadata in the database - effectively 
        % destroying it. 
        
            teLine;
            teEcho('\nTHIS WILL CLEAR ALL METADATA AND DESTROY THE DATABASE!\n');
            if ~obj.confirmDestructiveOperation, return,  end
            
            % clear metadata
            obj.md = {};
            obj.prMetadataDirty = true;
            obj.saveMetadataToFilesystem
            teEcho('Metadata cleared.\n');
            
        end
        
        function DeleteRecord(obj, guid)
        % deletes one record only from the database. The record is selected 
        % by passing a GUID that refers to it. Only one GUID can be sent at
        % a time. This is permanent and data deleted is unrecoverable
        
            % check input
            if ~ischar(guid) 
                error('Must pass a valid GUID as an input argument.')
            end
            
            % query for to-be-deleted record
            [guidsToDelete, ~, rowsToDelete] =...
                obj.GetField('GUID', 'GUID', guid);
            if isempty(guidsToDelete)
                % record not found
                error('Record not found for GUID [%s]', guid)
            end
            
            % confirm
            teLine
            teEcho('You are about to delete the following record:\n\n');
            disp(struct(obj.Metadata{rowsToDelete}))
            if ~obj.confirmDestructiveOperation, return, end
            
            % delete
            obj.md(rowsToDelete) = [];
            obj.prMetadataDirty = true;
            teEcho('Deleted record for GUID [%s].\n', guid);
            
        end
        
        function RepairPaths(obj)
        % Recurses through the file system for all external data. For each 
        % item found, extract the type (folder name) and GUID (from
        % filename). Find the corresponding metadata and either:
        %   1) if the path to the external data does not exist, add it to
        %   the metadata;
        %   2) or, if the path exists, update it to match the actual
        %   location of the data
        %
        % This should only be run when a repair is absolutely necessary.
        % There is a risk that orphaned external data will be added to
        % metadata, or even overwrite good data. Use with extreme caution.
        %
        % At present this hashes the contents of each file and only updates
        % the metadata if the files are identical.
        
            stat = cmdStatus('Repairing database paths...');
        
            % find all files
            files = recdir(obj.Path_Data);
            
            % remove folders
            files(isfolder(files)) = [];
            numFiles = length(files);
            
        % extract type
        
            % we want to extract the first subfolder for each file.
            % However, the absolute path has an unknown number of folders
            % that the actual data folder resides in. Find the depth of
            % these "root" subfolders
            folderDepth_db = length(strsplit(obj.Path_Data, filesep));
            
            % loop through each file, and split the path into each
            % (sub)folder. Find the second path AFTER the root path - this
            % will be the type
            types = cell(numFiles, 1);
            guids = cell(numFiles, 1);
            replaced = false(numFiles, 1);
            reason = cell(numFiles, 1);
            for f = 1:numFiles
                
                stat.Status = sprintf('Repairing database paths [%d of %d]...\n',...
                    f, numFiles);
                
                parts = strsplit(files{f}, filesep);
                
                % find type
                types{f} = parts{folderDepth_db + 1};
                
                % find GUID
                subParts = strsplit(parts{end}, '_');
                guids{f} = subParts{end - 1};
                
                % get metadata
                md = obj.GetMetadata('GUID', guids{f});
                path_md = md.Paths(types{f});
                pathsDifferent = ~isequal(path_md, files{f});
%                 filesIdentical = isequal(CalcMD5(files{f}, 'File'),...
%                     CalcMD5(path_md, 'File'));
                filesIdentical = true;
                if pathsDifferent && filesIdentical
                    replaced(f) = true;
                    path_repaired = strrep(files{f}, obj.Path_Data, '');
                    md.Paths(types{f}) = path_repaired;
                    [~, idx] = teLogFilter(obj.LogArray, 'GUID', md.GUID);
                    obj.md{idx} = md;
                else
                    replaced(f) = false;
                    if ~pathsDifferent
                        reason{f} = 'path up to date';
                    elseif ~pathsDifferent && ~filesIdentical
                        reason{f} = 'paths different, hash mismatch';
                    else
                        reason{f} = 'unknown';
                    end
                end
                
            end
            
            smry = table;
            smry.GUID = guids;
            smry.type = types;
            smry.path_db = files;
            smry.replaced = replaced;
            smry.reason = reason;
            
            
            
        
        end
            
                
        % query
        function val = GetGUID(obj, varargin)
        % query the database using field/value pairs, and return the
        % GUID(s) of the queried data
        
            val = obj.GetField('GUID', varargin{:});
            
        end
        
        function [md, guid] = GetMetadata(obj, varargin)
        % return entire metadata chunk(s). We find them by first making a
        % table of all metadata, then querying it using the input arguments
        % passed in. In general these should be variable/value pairs, used
        % to select a database field (e.g. 'ID') and filter by value (e.g.
        % '101'). If length(varargin) == 1, then we assume that the field
        % we are querying is 'GUID' and that the single element in varargin
        % is the value we are searching for. 
            
            if obj.Debug, tic, end
            
            % get log array
            la = obj.LogArray;
            
            % if no variable was passed, we assume guid
            if length(varargin) == 1
                varargin = ['GUID', varargin];
            end
            
            % query database and get a logical index of all records
            % indicating which were selected
            [tab, idx] = teLogFilter(la, varargin{:});
            if isempty(tab)
                md = [];
                guid = [];
                return
            end
            
            % get raw metadata 
            md = obj.Metadata;
            
            % filter metadata 
            md = md(idx);
            
            % extract guids
            guid = tab.GUID;
            
            % if scalar results, extract from cell array
            if numel(md) == 1 && iscell(md)
                md = md{1};
                guid = guid{1};
            end
            
            if obj.Debug, obj.AddLog(sprintf('Built metadata in %.4fs\n', toc)), end
            
        end
        
        function [val, guid] = GetPath(obj, type, varargin)
            
            if obj.Debug, tic, end
            
            guid = [];
            
            % get md
            [md, guid] = obj.GetMetadata(varargin{:});
            if isempty(md)
                val = [];
                return
            end
            
            % get path
            if length(md) > 1
                % more than one metadata returned, use arrayfun to get the
                % path from each one
                pth = cellfun(@(x) x.Paths(type), md, 'uniform', false);
            else
                pth = md.Paths(type);
            end
                
            if isempty(pth)
                val = [];
            else
                val = fullfile(obj.Path_Data, pth);
            end
            
            if obj.Debug, obj.AddLog(sprintf('Built path in %.4fs\n', toc)), end
            
        end
        
        function [val, guid, rowID] = GetField(obj, field, varargin)
        % query the database using field/value pairs, and return the
        % relevent field. This is a general purpose method that is called
        % by other methods (e.g. .GetGUID)
        
            if obj.Debug, tic, end
            
            if isempty(obj.Metadata)
                val = [];
                guid = [];
                return
            end
        
            % filter table
            tab = teLogFilter(obj.LogArray, varargin{:});
            
            % in order to handle cellstrs of multiple field names, in the
            % case of a single field (passed as char), put the field into a
            % cell array. This way we can interate through the cellstr and
            % return all fields
            if ischar(field)
                field = {field};
            end
            
            % check that we (now) have a cellstr of field names
            if ~iscellstr(field)
                error('''field'' must be either char or a cell array of strings.')
            end
            
            % lookup
            res = cellfun(@(x) obj.getFieldFromTable(tab, x), field,...
                'uniform', false);
            
            % get guid
            guid = obj.getFieldFromTable(tab, 'GUID');
            
            % cat and return
            val = horzcat(res{:});
            
            % if single row, strip from cell array
            if numel(val) == 1
                val = val{:};
                guid = guid{:};
            end
            
            % optionally return rowID, the indices in the metadata array of
            % the fields that form the returned query. This allows for
            % direct manipulation (if you are the server) of the metadata
            % array in order to support things such as deleting a record
            if nargout == 3
                rowID = tab.logIdx;
            end
            
            if obj.Debug, obj.AddLog(sprintf('Built field in %.4fs\n', toc)), end
                                      
        end
        
        function [data, guid] = GetVariable(obj, field, varargin)
        % queries the database and attempts to load, and return, the actual
        % data (as opposed to just its path). Only works for supported
        % filetypes - essentially, those that can be loaded into Matlab -
        % so .mat, .csv, .xlsx, .txt.
        
            % get paths and guids. Note that since we call GetPath, we are
            % getting an absolute path (not a locater path)
            [pth, guid] = obj.GetPath(field, varargin{:});
            if isempty(pth), data = []; return, end
            
        % check file type. if multple records were returned, we need to
        % do this for each path, so we use cellfun and place scalar
        % records into a cell array first 
        
            if ~iscell(pth), pth = {pth}; end
        
            % note empty records
            empty = cellfun(@isempty, pth);
            if all(empty), data = []; return, end
        
            % determine file types by extension
            ext = cell(size(pth));
            [~, ~, ext(~empty)] = cellfun(@fileparts, pth(~empty), 'uniform', false);
            
            % compare to loadable file types
            isLoadable = false(size(pth));
            isLoadable(~empty) = ismember(ext(~empty),...
                obj.CONST_LoadableFiletypes(:, 1));
            
            % load where possible
            data = cell(size(ext));
            for d = 1:length(data)
                
                if ~empty(d) && isLoadable(d)
                    
                    % lookup load function for this file type
                    loadIdx     =...
                        strcmpi(ext{d}, obj.CONST_LoadableFiletypes(:, 1));
                    loadFun     =...
                        str2func(obj.CONST_LoadableFiletypes{loadIdx, 2});
                    
                    % build the path to the data
                    path_data = pth{d};
                    
                    % load the data
                    tmp = feval(loadFun, path_data);
                    
                    % remove the data from the struct it was loaded into.
                    % Note that this assumes a struct with a single field
                    % (or at least it only takes the first field)
                    if isstruct(tmp)
                        fnames = fieldnames(tmp);
                        data{d} = tmp.(fnames{1});
                    else
                        % if not a struct, just take the data
                        data{d} = tmp;
                    end
                    
                end
                
            end
            
            % if only a single dataset, break out from cell array
            if numel(data) == 1
                data = data{1};
            end
            
        end
        
        function tab = GetTable(obj, varargin)
            
            if obj.Debug, tic, end
            
            % get log array
            la = obj.LogArray;
            
            % if no variable was passed, we assume guid
            if length(varargin) == 1
                varargin = ['GUID', varargin];
            end
            
            % query database and get a logical index of all records
            % indicating which were selected
            tab = teLogFilter(la, varargin{:});
            
            if obj.Debug, obj.AddLog(sprintf('Built table in %.4fs\n', toc)), end
            
        end        

        % get / set
        function val = get.Metadata(obj)
            val = obj.md;
        end
        
        function val = get.ClientDetails(obj)
            
            % get number of users 
            numUsers = length(obj.prClientIP);
            
            if numUsers == 0
                % if no users, return empty
                val = [];
                
            else
                % loop through users and build string of 'IP:port (user)'
                val = cell(numUsers, 1);
                for u = 1:numUsers
                    if ~isempty(obj.prClientUser{u})
                        % is username is available, use it...
                        val{u} = sprintf('%s:%d (%s)', obj.prClientIP{u},...
                            obj.prClientPort(u), obj.prClientUser{u});
                        
                    else
                        % ...otherwise just use IP and port
                        val{u} = sprintf('%s:%d', obj.prClientIP{u},...
                            obj.prClientPort(u));
                    end
                end
            end
        end
                
    end
    
    methods (Access = private)
        
        function saveMetadataToFilesystem(obj, varargin)
            
            if ~obj.prConnectedToDatabase || ~obj.prMetadataDirty, return, end
            
            obj.AddLog('Saving metadata...\n');
            
            md = obj.md;
            
            % main db
            try
                save(obj.Path_Metadata, 'md')
            catch ERR_saveMetadata
                error('Error saving metadata to disk:\n\n%s',...
                    ERR_saveMetadata.message)
            end
            
            obj.AddLog('Updated metadata on disk\n');
            
            % backup db
            if ~isempty(obj.Path_Backup)
                try
                    save(obj.Path_Backup_Metadata, 'md')
                catch ERR_saveMetadata
                    error('Error saving backup metadata to disk:\n\n%s',...
                        ERR_saveMetadata.message)
                end
            end
            
            obj.prMetadataDirty = false;
        end
        
        function loadAccessList(obj)
            if exist(obj.CONST_path_accessList, 'file')
                tmp = load(obj.CONST_path_accessList);
                obj.prAccessList = tmp.accessList;
            else
                obj.prAccessList = getMacAddress;
            end
        end
        
        function confirmed = confirmDestructiveOperation(obj)
            
            confirmed = false;
            
            resp = input('\nAre you sure you want to do this? (y/n) > ', 's');
            if ischar(resp) && instr(lower(resp), 'y')
                code = randi(9, 1, 5);
                codeStr = strrep(num2str(code), ' ', '');
                teEcho('To confirm, enter the following code: %s',...
                    codeStr);
                resp = input('> ', 's');
                if ~isequal(resp, codeStr)
                    error('Invalid code entered.')
                else
                    confirmed = true;
                end
            else
                confirmed = false;
                return
            end
            
            % back up just in case
            file_backup = fullfile(tempdir, sprintf('metadata_backup_%s.mat',...
                datestr(now, 30)));
            copyfile(obj.Path_Metadata, file_backup);
            teEcho('Metadata was backed up to: %s\n', file_backup);
        end
        
    end
    
end

    