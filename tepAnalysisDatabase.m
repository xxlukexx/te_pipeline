classdef tepAnalysisDatabase < handle
    
    properties 
        Verbose = false
        Debug = false
    end

    properties (Dependent, SetAccess = private)
        Path_Database
        Path_Backup
        Path_Data
        Path_Metadata
        Path_Ingest
        Path_Update
        Name
        Valid
        NumDatasets 
        LogArray
        Table
    end
    
    properties (Hidden, Dependent, SetAccess = private)
        Path_Backup_Data
        Path_Backup_Metadata
        Path_Backup_Ingest
        Path_Backup_Update
    end
    
    properties (SetAccess = private)
        Log = {}
    end
    
    properties (Access = protected)
        prPath_DB
        prPath_Backup
        prName
        prMetadataHash
        md = {}
        prConnectedToDatabase = false
        prLastDataSent
        prLastDataSent_ser
    end
    
    properties (Abstract, Dependent, SetAccess = private)
        Metadata
    end
    
    properties (Constant)
        CONST_ReadTimeout = 30   % in seconds
        CONST_LoadableFiletypes = {...
            '.mat',         'load'      ;...
            '.txt',         'load'      ;...
            '.xlsx',        'readtable' ;...
            '.csv',         'readtable' ;...
            }
    end
    
    methods
        
        function CreateDatabase(obj, path_db, name, path_backup)
        % creates a new instance of an analysis database in path_db, and
        % calls it name. This method will also automatically connect to the
        % newly created database 
        
            % check presence of input args
            if ~exist('path_db', 'var') || isempty(path_db)
                error('Must supply path_db - a path to where the new database should be stored.')
            end
            
            if ~exist('name', 'var') || isempty(name)
                error('Must provide a name for the new database.')
            end
            
            if ~exist('path_backup', 'var') || isempty(path_backup)
                path_backup = '';
            end
            
            % check format of input args
            if ~ischar(path_db)
                error('path_db must be a string.')
            end
            
            if ~isempty(path_backup) && ~ischar(path_backup)
                error('path_backup must be a string.')
            end
            
            if ~ischar(name)
                error('name must be a string.')
            end
            
            % set name
            obj.prName = name;
            
            % to ensure we don't accidentally overwrite an existing
            % database, validate the supplied path_db - if an error is
            % thrown or it is not returned valid then we're good to go
            try
                val = obj.validateDatabasePath(fullfile(path_db, name));
            catch ERR
                val = false;
            end
            if val
                error('Existing database found at path, will not overwrite: %s',...
                    path_db)
            end

            % check path exists. Note that this is the path of the
            % containing folder - we haven't yet built the path to the
            % actual database folder
            if ~exist(path_db, 'dir')
                % attempt to make path
                tryToMakePath(path_db)
            end
            
            if ~isempty(path_backup) && ~exist(path_backup, 'dir') 
                tryToMakePath(path_backup)
            end
            
            % build path to database
            obj.prPath_DB = fullfile(path_db, name);
            if ~isempty(path_backup)
                obj.prPath_Backup = fullfile(path_backup, name);
            end

            % create database folders
            try
                % main db
                tryToMakePath(obj.Path_Database)
                tryToMakePath(obj.Path_Data)
                tryToMakePath(obj.Path_Ingest)
                tryToMakePath(obj.Path_Update)
                
                % backup db
                if ~isempty(path_backup)
                    % folders
                    tryToMakePath(obj.Path_Backup_Data)
                    tryToMakePath(fullfile(obj.prPath_Backup, 'ingest'))
                    tryToMakePath(fullfile(obj.prPath_Backup, 'update'))
                    % backup config
                    config.path_backup = path_backup;
                    save(fullfile(obj.Path_Database, 'config.mat'), 'config')
                end
                
                catch ERR_makePaths
                error('Error when trying to make paths. Check permissions.')
            end
            
            % create empty log array
            md = {};
            obj.md = md;
            save(obj.Path_Metadata, 'md')
            if ~isempty(path_backup)
                save(obj.Path_Backup_Metadata, 'md')
            end
            
            obj.prConnectedToDatabase = true;
        end
        
        function AddLog(obj, varargin)
            fprintf('[%s] ', datestr(now, 'YYYYmmDD HH:MM:SS'));
            li = teEcho(sprintf(varargin{:}));
            obj.Log{end + 1} = li;
        end
            
        % netcode
        
        function [data, suc] = NetReceiveVar(obj, conn)
        % wait for a variable to be sent from a connection and send an
        % acknowledgement
                
            % get data
            [suc_receive, data] = obj.netReceiveData(conn);

            if ~suc_receive
                error('Error receiving variable.')
            end

            try
                data = dunzip(data);
                data = getArrayFromByteStream(uint8(data));
                suc_deser = true;
            catch ERR_deser
                suc_deser = false;
            end
            
            if ~suc_deser && exist('ERR_deser', 'var')
                error('Error receiving variable:\n\n%s',...
                    ERR_deser.message)
            end
            
            suc = suc_receive && suc_deser;
            
        end
        
        function NetSendVar(obj, conn, data)
            
            tic
%             % check whether data has changed - if it's the same data as
%             % last time then we reuse this, rather than serialising again
%             % (which is slow)
%             if isequal(data, obj.prLastDataSent)
%                 data = obj.prLastDataSent_ser;
%                 
%             else
%                 % store
%                 obj.prLastDataSent = data;
                
                % serialise variable
                data = getByteStreamFromArray(data);
                
%                 % store
%                 obj.prLastDataSent_ser = data;
%                 
%             end            
%             fprintf('Serialise: %.4f\n', toc);
            
            % compress
%             data = uint8(data);
            tic
            try
                data = dzip(data);
            catch ERR
                % leave data uncompressed
                warning('dzip failed (%s), not using compression.', ERR.message)
                data = uint8(data);
            end
%             fprintf('Compress: %.4f\n', toc);
            
            % get the size of the response
            sz = length(data);
            
            tic
            % hash data
            hash = CalcMD5(data);
%             fprintf('Hash: %.4f\n', toc);

        % send size

            pnet(conn, 'printf', sprintf('%d\n', sz))
            obj.netAwaitReady(conn);
            
        % send hash
            
            pnet(conn, 'printf', sprintf('%s\n', hash))
            obj.netAwaitReady(conn);

        % send data

            tic
            
            pnet(conn, 'write', data);
            obj.netAwaitReady(conn);
            b = whos('data');
%             fprintf('Send data (%.2fMb): %.4f\n', b.bytes / 1e6, toc);
            
        end
        
        function err = NetError(obj, conn, err)

            ack = '-1';

            % send ack and error message to client
            pnet(conn, 'printf', sprintf('%s\n', ack));
            pnet(conn, 'printf', sprintf('%s\n', err));
            
            obj.AddLog('Remote execution error: %s\n', err);
                            
        end
        
        function err = NetGET(obj, conn, data)
        % the GET command essentially call a class method
        % and returns the result
        
            err = true;

            % for GET, data cannot be empty. It has to be at
            % least one element long, that first element being
            % the property or method that is being queried
            if isempty(data)

                err = obj.NetError(conn,...
                    'Missing input argument for GET.');
                return

            end

            % check that the first arg is either a property or
            % a method
            if ~ismethod(obj, data{1}) && ~isprop(obj, data{1})

                err = obj.NetError(conn,...
                    sprintf('Unknown command %s.', data{1}));

                % move on to next connection (this
                % connection has nothing to offer now that
                % it has errored)
                return

            end

        % convert protocol commands to a string that can be
        % evaluated on the local class instance

            if length(data) == 1
            % if data is one word then we treat this as a
            % class method call on the server, from the
            % client. For example, if data is {'Metadata'}
            % then we simply call obj.Metadata (on this,
            % the server) and return the result to the
            % client. 

                str = sprintf('obj.%s', data{1});

            elseif length(data) > 1
            % if data is more than one word, we treat the
            % first word as the method call on the server,
            % and any subsequent words as input arguments
            % to that method

                % extract arguments
                args = data(2:end);
                
%                 % put any char arguments in quotes
%                 arg_char = cellfun(@(x) strcmp(x(1), '''') && strcmp(x(end), ''''), args);
%                 args(arg_char) = cellfun(@(x) sprintf('''%s''', x),...
%                     args(arg_char), 'uniform', false);
                
                % build expression
                str = sprintf('obj.%s(', data{1});
                str = [str, sprintf('%s,', args{:})];
                str(end) = ')';

            end

        % execute the command locally

            try
                
                % we don't know how many output arguments to send back. We
                % can use a hacky workaround to nargout for class methods,
                % but this doesn't work for properties (where nargout == 1
                % by definition). So figure out which situation we're in...
                
                if ~isprop(obj, data{1})
                    numOut = nargout(sprintf(...
                        'tepAnalysisServer>tepAnalysisServer.%s', data{1}));
                else
                    numOut = 1;
                end
                
                % if numOut > 1, then use this horrible hacky shit
                % workaround by construction the entire expression,
                % including variable length cell array (res) for results,
                % and execute the lot with evalc. Otherwise, evaluate just
                % the right hand side of the expression with eval and store
                % the results in a scalar
                if numOut > 1
                    res = cell(1, numOut);
                    cmd = 'res{1}';
                    for i = 2:numOut
                        cmd = [cmd, sprintf(', res{%d}', i)];
                    end
                    str = ['[', cmd, '] = ', str];
                    evalc(str);
                    
                else
                    res = eval(str);
                    
                end
                
            catch ERR_execute
                err = obj.NetError(conn,...
                    ERR_execute.message);
                return
            end

            obj.NetSendVar(conn, res);
            
            err = false;
                        
        end
        
        % get / set
        function val = get.Path_Database(obj)
            val = obj.prPath_DB;
        end
        
        function val = get.Path_Backup(obj)
            val = obj.prPath_Backup;
        end
        
        function val = get.Name(obj)
            val = obj.prName;
        end
        
        function val = get.Valid(obj)
            val = strcmpi(obj.prStatus, 'connected');
        end
                
        function val = get.Path_Data(obj)
            val = obj.buildDynamicPath('data');
        end
        
        function val = get.Path_Metadata(obj)
            if isempty(obj.Path_Database)
                val = [];
            else
                val = fullfile(obj.Path_Database, 'metadata.mat');
            end
        end
        
        function val = get.Path_Ingest(obj)
            val = obj.buildDynamicPath('ingest');
        end
        
        function val = get.Path_Update(obj)
            val = obj.buildDynamicPath('update');
        end
        
        function val = get.Path_Backup_Data(obj)
            val = obj.buildDynamicBackupPath('data');
        end
        
        function val = get.Path_Backup_Metadata(obj)
            if isempty(obj.Path_Backup)
                val = [];
            else
                val = fullfile(obj.Path_Backup, 'metadata.mat');
            end
        end
        
        function val = get.Path_Backup_Ingest(obj)
            val = obj.buildDynamicBackupPath('ingest');
        end
        
        function val = get.Path_Backup_Update(obj)
            val = obj.buildDynamicBackupPath('update');
        end        
        
        function val = get.NumDatasets(obj)
            val = length(obj.Metadata);
        end
        
        function val = get.LogArray(obj)
            val = cellfun(@(x) x.Struct, obj.Metadata, 'uniform', false);
%             val = {obj.Metadata.Struct};
        end
        
        function val = get.Table(obj)
            la = obj.LogArray;
            if isempty(la)
                val = [];
            else
                val = teLogExtract(la);
            end
        end
        
    end
    
    methods (Access = protected)
        
        function val = buildDynamicPath(obj, pathName)
            if isempty(obj.Path_Database)
                val = [];
            else
                val = fullfile(obj.Path_Database, pathName);
            end
        end
        
        function val = buildDynamicBackupPath(obj, pathName)
            if isempty(obj.Path_Backup)
                val = [];
            else
                val = fullfile(obj.Path_Backup, pathName);
            end
        end
        
        function md = checkForLatestMetadata(obj)
        % this method returns the latest metadata. The latest metadata may
        % be that which is in memory, or if an update has occurred then it
        % may be what is on disk (note that the server is expected to keep
        % a master copy of the most recent version of the metadata in
        % memory, but the same is not true for the client. This method can
        % be called from either a server or client instance). 
        %
        % To determine whether we need to read from disk or not, at each
        % disk read (including the initial one when a database is
        % connected) we hash the metadata file. If on a subsequent call to
        % this method the hash has changed, then we read from disk.
        % Otherwise, we read from memory. 
        
            % get hash of metadata on disk
            hash_fs = CalcMD5(obj.Path_Metadata);
            
            % compare to previous hash (which may be empty, if this is the
            % first time this method has been called)
            changed = ~isequal(hash_fs, obj.prMetadataHash);
            
            % if changed, we read from disk and store in private property
            if changed
                % attempt to load metadata
                try
                    tmp = load(obj.Path_Metadata);
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
                
            end
            
            % now return the value from the private property
            md = obj.md;
            
        end
        
        function AssertIPAddress(~, val)
            if ~ischar(val)
                error('Invalid IP address or hostname.')
            end
        end
        
        function val = validateDatabasePath(obj, path_db)
            
            % check path 
            if ~exist(path_db, 'dir') 
%                 obj.DisconnectFromServer
                error('Path not found. Ensure you have access to:\n\n%s',...
                    path_db)
            end
            
            % check for valid structure
            obj.prPath_DB = path_db;
            val =...
                exist(obj.Path_Data, 'dir') &&...
                exist(obj.Path_Metadata, 'file') &&...
                exist(obj.Path_Ingest, 'dir') &&...
                exist(obj.Path_Update, 'dir');  
            
            if ~val
                error('Database subfolders not found.')
            else
                obj.AddLog('Connected to file system at: %s\n', path_db);
            end
            
        end
        
        function val = getFieldFromTable(~, tab, field)
            
            if isempty(tab)
                val = [];
                return
            end
            
            % check that field exists
            if ~ismember(field, tab.Properties.VariableNames)
                warning('Field %s not found in database.', field)
                val = [];
                return
            end
            
            % return GUIDs
            if isempty(tab)
                val = [];
            else
                val = tab.(field);
            end
            
        end
        
        function [val, err] = validateMetadata(obj, md, isUpdate)
        % the isUpdate flag determines whether we are updating existing
        % metadata. In the case of an ingest of new data, isUpdate will
        % be false the guid of the new data CANNOT exist in the
        % database (if it does, validation will fail). OTOH, if we are
        % updating existing metadata, then we want to ensure that the
        % data DOES exist in the database (and if it DOESN'T then the
        % validation will fail)
           
            % determine where we are validating one single metadata chunk
            % (a struct) or an array (cell array of structs)
            if iscell(md)
                % if md is a cellstruct then iteratively call this function
                % with each metadata chunk and collate the results
                [val, err] = cellfun(@obj.validateMetadata, md, canExist,...
                    'uniform', false);
                return
            end
            
            % defaults
            val = false;
            err = 'unknown error';
            
            % check data type
            if ~isa(md, 'teMetadata')
                err = 'Metadata chunk must be a teMetadata, or cell arrays of teMetadatas.';
                return
            end
            
            % chunk must be scalar (at least for now)
            if ~isscalar(md)
                err = 'Metadata chunk must be scalar (not a struct array).';
                return
            end
            
            % check that GUID is present (the only field that must be in a
            % metadata chunk)
            if ~ischar(md.GUID) || isempty(md.GUID)
                err = 'Missing or empty GUID field.';
                return
            end
            
            % check whether the GUID already exists, by querying the
            % database and looking for an empty response
            guid_test = obj.GetGUID('GUID', md.GUID);
            guid_exists = ~isempty(guid_test);
            
            % determine whether the guid existing is a good thing or not
            if isUpdate && ~guid_exists
                err = sprintf('No existing record found for GUID %s.',...
                    md.GUID);
                return
            elseif ~isUpdate && guid_exists
                err = sprintf('Record already exists with GUID of %s.',...
                    md.GUID);
                return
            end
            
            val = true;
            err = '';
            
        end
        
        function [suc, data] = netReceiveData(obj, conn)
            
            data = [];
            suc = false;
            
            % await size
            sz = str2double(pnet(conn, 'readline'));
            if isempty(sz) || isequal(sz, -1)
                err = pnet(conn, 'readline');
                if isequal(err, -1)
                    error('Server did not respond.')
                else
                    error('Remote error: %s', err)
                end
            end
            obj.netSendReady(conn);
            
            % await hash
            hash_remote = pnet(conn, 'readline');
            if isempty(hash_remote) || isequal(hash_remote, -1)
                error('Failed to receive remote hash.')
            end
            obj.netSendReady(conn);
            
            % await data
            data = pnet(conn, 'read', sz, 'uint8');
            if isempty(data) || isequal(data, -1)
                error('Failed to receive data.')
            end            
            obj.netSendReady(conn);

            % check hash
            hash_local = CalcMD5(data);
            suc = isequal(hash_local, hash_remote);
            
        end
        
        function suc = netAwaitReady(~, conn)
        % awaits a READY command from the other end of the connection
        
            ready = pnet(conn, 'readline');
            
            % check for net error
            if isequal(ready, '-1')
                err = pnet(conn, 'readLine');
                error('Remote error: %s', err)
            end
            
            suc = isequal(ready, 'READY');
            
        end
        
        function netSendReady(~, conn)
            
            pnet(conn, 'printf', sprintf('READY\n'));
            
        end
        
        function md_c = convertMetadataObjectArrayToCellArray(obj, md_o)
        % old versions of the database used an object array of teMetadata
        % objects. This caused problems and has changed to a cell array of
        % scalar teMetadatas. This method converts from the old to the new
        % format. It is called when metadata are loaded, so that older
        % versions of the data can be automatically upgraded to the new
        % format. 
        
            if ~isa(md_o, 'teMetadata')
                error('Input metadata must be an object array.')
            end
            
            md_c = arrayfun(@(x) x, md_o, 'uniform', false);
            
        end
        
    end
    
end

    