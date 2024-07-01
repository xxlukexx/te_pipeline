classdef tepAnalysisClient 
    
    properties (Dependent, SetAccess = private)
        MongoDB
    end
    
    properties (Hidden, SetAccess = private)
        mg tepMongo
    end
    
    methods
        
        function obj = tepAnalysisClient(mongo_ip, mongo_port, mongo_db_name)
            
            % todo - add user and password
            
            if ~exist('mongo_ip', 'var') || isempty(mongo_ip)
                mongo_ip = '127.0.0.1';
            end
            if ~exist('mongo_port', 'var') || isempty(mongo_port)
                mongo_port = 27017;
            end
            if ~exist('mongo_db_name', 'var') || isempty(mongo_db_name)
                mongo_db_name = 'adb';
            end
            
            try
                obj.mg = tepMongo(mongo_ip, mongo_port, mongo_db_name);
            catch ERR
                error('Error whilst connecting to MongoDB:\n\n%s', ERR.message)
            end
            if ~obj.mg.isopen
                error('Mongo connection failed.')
            end
            if ~obj.mg.collectionexists('metadata')
                error('Metadata collection not found in MongoDB.')
            end
            
        end
        
        function [md, GUID] = GetMetadata(obj, varargin)
            
            query = obj.parseToQuery(varargin{:});
            
            if isempty(query)
                res = obj.mg.find('metadata');
            else
                res = obj.mg.find('metadata', 'query', query);
            end
            
            % convert to teMetadata
            [md, GUID] = obj.results2metadata(res);
            
        end
        
        function [val, GUID] = GetField(obj, field, varargin)
            
            % make mongodb projection document to return just the specified
            % fields
            if ~iscell(field), field = {field}; end
            numFields = length(field);
            proj = '{';
            for f = 1:numFields
                proj = [proj, sprintf('"%s": 1,', field{f})];
            end
            proj = [proj, ' "_id":0}'];
            
            % amend query so that we only return values that have the
            % sought-for field
            for f = 1:numFields
                varargin = [varargin, field{f}, '{"$exists":true}'];
            end
            
            % prepare query (if present)
            query = obj.parseToQuery(varargin{:});
            
            % execute
            if isempty(query)
                val = obj.mg.find('metadata', 'projection', proj);
            else
                val = obj.mg.find('metadata', 'query', query, 'projection', proj);
            end            
            
%             % figure out how to return the data
%             if all(cellfun(@isstruct, val))
%                 % return struct array
%                 val = 
            
%             % get metadata
%             [md, GUID] = obj.GetMetadata(varargin{:});
%             
%             % wrap scalar md in cell
%             if ~iscell(md)
%                 md = {md};
%             end
%             
%             % convert all to struct
%             s = cellfun(@struct, md, 'uniform', false);
%             
%             % check if field exists in any element
%             anyExists = any(cellfun(@(x) isfield(x, field), s));
%             if ~anyExists
%                 error('Field %s not found in any result.', field)
%             end
%             
%             % attempt to extract field value from each element
%             val = cell(size(s));
%             for i = 1:length(s)
%                 if isfield(s{i}, field)
%                     val{i} = s{i}.(field);
%                 else
%                     val{i} = nan;
%                 end
%             end
%             
%             % unpack scalar from cell array
%             if length(val) == 1, val = val{1}; end
            
        end
        
        function GUID = InsertMetadata(obj, md)
            
            if ~exist('md', 'var') || ~isa(md, 'teMetadata')
                error('Must pass a valid teMetadata object.')
            end
            
            GUID = md.GUID;
            if obj.metadataIsInDB(md)
                error('Metadata with GUID %s already exists in the database, use ReplaceMetadata to change it.', md.GUID)
            end
            
            obj.insertMetadata(md);
            
        end
        
        function GUID = UpdateMetadata(obj, md, upsert)
            
            if ~exist('upsert', 'var') || isempty(upsert)
                upsert = false;
            end            
            
            if ~exist('md', 'var') || ~isa(md, 'teMetadata')
                error('Must pass a valid teMetadata object.')
            end
            
            GUID = md.GUID;
            if ~obj.metadataIsInDB(md)
                error('Metadata with GUID %s does not already exist in the database, use InsertMetdata to insert it.', md.GUID)
            end
            
            obj.updateMetadata(md, upsert);
            
        end
        
        function GUID = UpsertMetadata(obj, md)
            
            if ~exist('md', 'var') || ~isa(md, 'teMetadata')
                error('Must pass a valid teMetadata object.')
            end            
            
            GUID = obj.updateMetadata(md, true);
            
        end
        
        function GUID = ReplaceMetadata(obj, md)
            
            if ~exist('md', 'var') || ~isa(md, 'teMetadata')
                error('Must pass a valid teMetadata object.')
            end
            
            GUID = md.GUID;
            if ~obj.metadataIsInDB(md)
                error('Metadata with GUID %s does not already exist in the database, use InsertMetdata to insert it.', md.GUID)
            end
            
            obj.replaceMetadata(md);
            
        end
        
        function InsertOrReplaceMetadata(obj, md)
            
            if ~exist('md', 'var') || ~isa(md, 'teMetadata')
                error('Must pass a valid teMetadata object.')
            end
            
            if obj.metadataIsInDB(md)
                obj.replaceMetadata(md);
            else
                obj.insertMetadata(md);
            end
            
        end
        
        function tab = Table2DB(obj, field, tab, key_db, key_tab)
            
            if ~exist('key_db', 'var') || isempty(key_db)
                key_db = '_id';
                fprintf('No database key supplied, defaulting to "ID".\n')
            end
            if ~exist('key_tab', 'var') || isempty(key_tab)
                key_tab = 'ID';
                fprintf('No table key supplied, defaulting to "ID".\n')
            end            
            
            % check that table key exists in table
            vars_tab = tab.Properties.VariableNames;
            if ~ismember(key_tab, vars_tab)
                error('Table key "%s" not found in table.', key_tab)
            end
            
            % check that key is unique
            [~, i, s] = unique(tab.(key_tab));
            if length(i) ~= length(s)
                error('Table key is not unique, this is not yet supported.')
            end
            
            % convert table to struct array
            s = table2struct(tab);
            
            % prepare output columns in table
            tab.db_insert_update = repmat({'none'}, size(tab, 1), 1);
            tab.db_GUID = repmat({'NONE'}, size(tab, 1), 1);

            numRows = length(s);
            findQuery = cell(numRows, 1);
            json = cell(numRows, 1);
            for i = 1:numRows
                
                % get metadata if it exists, otherwise create a new one
                md = obj.GetMetadata(key_db, s(i).(key_tab));
                if isempty(md)                    
                    md = teMetadata;
                    md.GUID = GetGUID;
                    md.(key_db) = tab.(key_tab){i};
                    tab.db_insert_update{i} = 'insert';
                else
                    tab.db_insert_update{i} = 'update';
                end
                
                % build nested field structs (if needed)
                dots = strsplit(field, '.');
                numFields = length(dots);
                fld = sprintf('%s', dots{1});
                if numFields > 1
                    for f = 2:numFields
                        fld = sprintf('%s.%s', fld, dots{f});
                    end
                end
                cmd = sprintf('md.%s = s(%d);', fld, i);
                eval(cmd)
                
                % build find query and JSON
                findQuery{i} = obj.parseToQuery(key_db, s(i).(key_tab));
                json{i} = md.JSON;
                
                % update DB
                obj.updateMetadata(md, true);
                
                % update table
                tab.GUID{i} = md.GUID;
                
                fprintf('Updated document %d of %d [%s]...\n', i, numRows, md.GUID);
                
            end

        end
            
        function InsertXLS(obj, field, path_xls, key_db, key_xls)
            
            
%             if ~exist('key_db', 'var') || isempty(key_db)
%                 key_db = 'ID';
%                 fprintf('No database key supplied, defaulting to "ID".\n')
%             end
%             if ~exist('key_xlsx', 'var') || isempty(key_xlsx)
%                 key_xlsx = 'ID';
%                 fprintf('No Excel key supplied, defaulting to "ID".\n')
%             end
%             
%             if ~exist(path_xls, 'file')
%                 error('File not found: %s')
%             else
%                 tab = readtable(path_xls);
%             end
            
            
            
        end
        
        % get/set
        function val = get.MongoDB(obj)
            val = obj.mg;
        end
        
    end
    
    methods (Hidden)
        
        function query = parseToQuery(obj, varargin)
            
            argsAreChar = cellfun(@ischar, varargin);
            argsAreNumeric = cellfun(@isnumeric, varargin);
            argsAreCharOrNumeric = argsAreChar | argsAreNumeric;
            
            if all(cellfun(@isempty, varargin))
                
                % if no args passed, return an empty query, which will in turn
                % return all elements of the MongoDB collection
                query = '';
                return
                
            elseif length(varargin) == 1 && ischar(varargin{1})
                
                % assume the input arg is a MongoDB query string and return
                % this
                query = varargin{1};
                return
                
            elseif mod(length(varargin), 2) == 0 && all(argsAreCharOrNumeric)
                
                % an even number of input arguments pass, treat these as
                % field/filter pairs and construct a MongoDB query string
                query = obj.fieldFilterPairs2Query(varargin);
            
            else
                
                error('Unrecognised query format.')
                
            end
            
        end
    
        function query = fieldFilterPairs2Query(~, pairs)
        % convert field/filter pairs to a MongoDB query string
        %   e.g. {'ID', 'A3001'} means filter on field 'ID' for value
        %   'A3001'
        
            if mod(length(pairs), 2) ~= 0 || ~all(cellfun(@ischar, pairs) | cellfun(@isnumeric, pairs))
                error('Can only pass cell arrays (of strings, cahrs or numeric) with an even number of elements.')
            end
            
            fields = lower(pairs(1:2:end));
            filters = pairs(2:2:end);
            numPairs = length(fields);
            query = '{';
            for p = 1:numPairs
                
                % detect wildcard
                if ischar(filters{p}) && contains(filters{p}, '*')
                    
                    re = regexptranslate('wildcard', filters{p});                    
                    query = sprintf('%s "%s": { $regex: ''%s'' } ', query, fields{p}, re);
                    
                % detect e.g. {"$exists":true} and insert directly without adding quotes    
                elseif ischar(filters{p}) && contains(filters{p}, '$')
                    
                    query = sprintf('%s "%s": %s ', query, fields{p}, filters{p});
                    
                % if numeric, construct query assuming integer value
                elseif isnumeric(filters{p}) && isscalar(filters{p})
                    
                    query = sprintf('%s "%s": %d ', query, fields{p}, filters{p});
                    
                % if char, construct query using string value    
                elseif ischar(filters{p})
                    
                    query = sprintf('%s "%s": "%s" ', query, fields{p}, filters{p});
                    
                else
                    
                    error('Cannot parse query.')
                        
                end
                
                query = [query, ','];
                    
            end
%             query = [query, '}'];
            query(end) = '}';
            
        end
        
        function [md, GUID] = results2metadata(obj, res)
            if isempty(res)
                md = [];
                GUID = [];
                return
            end
            if ~iscell(res), res = {res}; end
            md = cellfun(@teMetadata, res, 'uniform', false);
            GUID = cellfun(@(x) x.GUID, md, 'uniform', false);
            if length(md) == 1, md = md{1}; end            
        end
        
        function val = hasMetadata(obj, varargin)
            
            query = obj.parseToQuery(varargin{:});
            res = obj.mg.find('metadata', 'query', query, 'limit', 1);
            val = ~isempty(res);
            
        end
        
        function val = metadataIsInDB(obj, md)
            
            val = obj.hasMetadata('GUID', md.GUID);
            
        end
        
    end
    
    methods (Hidden, Access = protected)
        
        function GUID = insertMetadata(obj, md)
            
            GUID = md.GUID;
            json = md.JSON;
            json(end) = [];
            json = sprintf('%s,"_id":"%s"}', json, md.GUID);
            obj.mg.insert('metadata', json);
            
        end
        
        function GUID = updateMetadata(obj, md, upsert)
            
            if ~exist('upsert', 'var') || isempty(upsert)
                upsert = false;
            end
            
            opt = com.mongodb.client.model.FindOneAndUpdateOptions;
            if upsert
                opt = opt.upsert(upsert);
            end
            
            GUID = md.GUID;
            findQuery = obj.parseToQuery('_id', md.GUID);
            suc = obj.mg.findOneAndUpdate('metadata', findQuery, md.JSON, opt);
            
        end 
            
        function GUID = replaceMetadata(obj, md)
            
            GUID = md.GUID;
            findQuery = obj.parseToQuery('_id', md.GUID);
            suc = obj.mg.findOneAndReplace('metadata', findQuery, md.JSON);
            
        end
        
    end
    
end
    
%     properties
%         HoldQuery
%     end
%     
%     properties (SetAccess = private)
%         Status = 'not connected'
%         User 
%     end
%     
%     properties (Dependent, SetAccess = private)
%         Metadata
%     end
%     
%     properties (Access = private)
%         prConn
%         prConnectedToServer = false
%         h_uitable = []
%         h_uitable_fig = []
%         prUITableUpdating = false
%     end 
%     
%     events
%         StatusChanged
%     end
%     
%     methods
%         
%         function obj = tepAnalysisClient
%             if ismac || islinux
%                 obj.User = getenv('USER');
%             elseif ispc
%                 obj.User = getenv('username');
%             else
%                 obj.User = 'unknown';
%             end
%         end
%         
%         function delete(obj)
%             obj.DisconnectFromServer
%         end
%         
%         function NetSendCommand(obj, conn, cmd)
%         % send a request to a connection and await acknolwedgement
%             
%             % first input arg is the command, others are data
%             if isempty(cmd)
%                 error('Must send a command as an input argument.')
%             end
% 
%             % send 
%             pnet(conn, 'printf', sprintf('%s\n', cmd));
%             
%             if ~obj.netAwaitReady(conn)
%                 error('Server did not respond.')
%             end
%             
%         end
%         
%         function [suc, ops, guid] = Ingest(obj, varargin)
%         % general-purpose function to ingest various data types. The 
%         % contents of varargin are used to determine which sub-method to
%         % call
%         
%             if ischar(varargin{1}) || iscellstr(varargin{1})
%                 % assume path to task engine session
%                 [suc, ops, guid] = obj.IngestTaskEngine(varargin{1});
%                 
%             elseif isa(varargin{1}, 'teMetadata')
%                 % directly ingest pre-prepared metadata
%                 [suc, ops, guid] = obj.IngestMetadata(varargin{:});
%                 
%             else
%                 error('Unrecognised data format.')
%                 
%             end
%             
%             obj.updateUITable
%             
%         end
%         
%         function [suc, ops, guid] = IngestTaskEngine(obj, path_session)
%             
%             guid = [];
%             suc = false;
%             
%             if ~obj.prConnectedToServer
%                 error('Cannot ingest until connected to server.')
%             end
%             
%         % determine whether one (char) session was passed, or an array
%         % (cellstr) of sessions
%         
%             if iscellstr(path_session)
%                 
%                 % iteratively re-call this method for each session path
%                 [ops, guid] =...
%                     cellfun(@obj.Ingest, path_session, 'uniform', false);
%                 
%                 % combine ops
%                 ops = horzcat(ops{:})';
%                 return
%             end
%             
%         % setup
%         
%             % blank operations struct
%             ops = {};
%             oc = 1;
%             ops{oc}.operation = 'ingest';
%             ops{oc}.path_session = path_session;
%             ops{oc}.success = false;
%             ops{oc}.outcome = 'unknown error';
% 
%             % check input args
%             if ~exist('path_session', 'var') || isempty(path_session)
%                 error('Must supply a path to session.')
%             end
%             
%             if ~ischar(path_session)
%                 error('Path to session must be a string.')
%             end
%             
%             % check path
%             if ~exist(path_session, 'dir') 
%                 ops{oc}.success = false;
%                 ops{oc}.outcome = sprintf('path not found: %s', path_session);
%                 return
%             end
%             
%             % attempt to load session into teData instance
%             try
%                 data = teData(path_session);
%                 guid = data.GUID;
%             catch ERR_Load
%                 ops{oc}.success = false;
%                 ops{oc}.outcome = ERR_Load.message;
%                 return
%             end
%             
%         % extract relevant fields from teData instance and store in
%         % metadata chunk
%             
%             % make metadata chunk and assign GUID
%             md = teMetadata;
%             md.GUID = data.GUID;
%             
%             % pull dynamic props from teData instance
%             numProps = length(data.DynamicProps);
%             for p = 1:numProps
%                 propName = data.DynamicProps{p};
%                 md.(propName) = data.(propName);
%             end
%             
%         % extract log and treat as external data. We first save the log to
%         % a temp file, so that we can copy/verify using the same method as
%         % for "real" external data
%         
%             % pull log array and put into variable
%             logArray = data.Log;
%             
%             % save to temp folder
%             file_fs = sprintf('logArray.mat');
%             path_src = fullfile(tempdir, file_fs);
%             save(path_src, 'logArray')
%             
%             % prepare paths
%             path_locate = 'log';
% 
%             % copy to filesystem
% %             oc = oc + 1;
% %             ops{oc} = struct;
%             [ops, md] =...
%                 obj.copyToFilesystem(path_src, path_locate, data.GUID,...
%                 ops, md);
%             
%             % delete temp
%             delete(path_src)
%                     
%         % process external data
% 
%             % loop through each external data, then through each path
%             % (since each external data can hold multiple files)
%             numExt = data.ExternalData.Count;
%             for e = 1:numExt
%                 
%                 extData = data.ExternalData(e);
%                 numPaths = extData.Paths.Count;
%                 
%                 for p = 1:numPaths 
%                     
%                     % path to source external data (to-be-ingested)
%                     path_src = extData.Paths.Items{p};
%                     
%                     % locater path within the DB (full dest path is
%                     % constructed by <DB PATH> / locater / filename)
%                     path_locate = extData.Paths.Keys{p};
%                 
%                     % copy
%                     oc = oc + 1;
%                     ops{oc} = struct;
%                     [ops, md] = obj.copyToFilesystem(path_src,...
%                         path_locate, data.GUID, ops, md);  
%             
%                 end
%                 
%             end
% 
%         % send metadata to server
%             
%             [suc, err] = obj.ServerIngest(md);
%             ops{1}.updateserver = suc;
%             ops{1}.updateservererror = err;
%             if ~suc
%                 ops{1}.success = false;
%                 ops{1}.outcome = err;
%                 return
%             end
%             
%         % check success of each operation and report overall ingest success
%             
%             % convert ops to table for ease of access
%             tab = teLogExtract(ops(2:end));
%             
%             % aggregate success of all operations
%             ops_suc = all(tab.success);
%             if ~ops_suc
%                 ops{1}.success = false;
%                 ops{1}.outcome = sprintf('%d ingest operations failed',...
%                     sum(~tab.success));
%                 return
%             else
%                 ops{1}.success = true;
%                 ops{1}.outcome = '';
%                 suc = true;
%             end
%             
%         end
%         
%         function [suc, ops, guid] = IngestMetadata(obj, md, varargin)
%         % takes a pre-prepared teMetadata and ingests it
%         
%             % check input arg
%             if ~isa(md, 'teMetadata')
%                 error('Must pass a teMetadata instance.')
%             end
%             
%             % check GUID 
%             if isempty(md.GUID)
%                 error('Cannot ingest metadata with an empty GUID.')
%             else
%                 guid = md.GUID;
%             end
%             
%             % it used to be that this method refused to ingest metadata
%             % which had elements in the paths collection on the basis that
%             % these would be local paths (not relative paths to the file
%             % system). Now the behaviour is to schedule these local paths
%             % for upload as external data. First the metadata must be
%             % ingested in order to create a GUID in the database, then the
%             % external data can be uploaded one at a time. This behaviour
%             % only happens if the 'uploadLocalPaths' flag is set when
%             % calling the function. 
%             if ~isempty(md.Paths)
% 
%                 if ismember('uploadLocalPaths', varargin)
% 
%                     % make a copy of the local paths
%                     sched = copyHandleClass(md.Paths);
%                     
%                     % empty the metadata's .Paths collection 
%                     md.Paths.Clear
%                     
%                     % prepare ops struct
%                     ops{2}.operation = 'upload_local_paths';
%                     ops{2}.success = false;
%                     ops{2}.outcome = 'unknown error';
%                     
%                 else
%                     
%                     sched = [];
%                     suc = false;
%                     ops{1}.success = false;
%                     ops{1}.outcome = 'Cannot ingest metadata unless .Paths collection is empty. Use the ''uploadLocalPaths'' flag when calling this method to upload existing local paths as external data';
%                     return
%                 end
%                 
%             else
%                 
%                 sched = [];
%                 
%             end
% 
%             % send metadata to server
%             ops{1}.operation = 'ingest_metadata';
%             [suc, err] = obj.ServerIngest(md);
%             ops{1}.updateserver = suc;
%             ops{1}.updateservererror = err;
%             if ~suc
%                 ops{1}.success = false;
%                 ops{1}.outcome = err;
%                 return
%             end            
%             
%             % upload any previously schedule external data
%             if ~isempty(sched)
%                 
%                 % check that all paths exist. Fail if any of them do not
%                 pathsExist = cellfun(@(x) exist(x, 'file'), sched.Items) == 2;
%                 if ~all(pathsExist)
%                     missingPathStr = sprintf(', %s', sched.Items(~pathsExist));
%                     ops{2}.success = false;
%                     ops{2}.outcome = sprintf('At least one path does not exist (or is not a path to a file). No external data were uploaded. That paths that failed are%s',...
%                         missingPathStr);
%                     return
%                 end
%                 
%                 % loop through local paths
%                 suc_upload = false(1, sched.Count);
%                 for e = 1:sched.Count
%                     
%                     % upload one path
%                     [suc_tmp, ~, md] = obj.UploadExternalData(...
%                         md, sched.Keys{e}, sched.Items{e});
%                     
%                     % record success
%                     suc_upload(e) = suc_tmp;
%                     
%                 end
%                 
%                 % check for failure to upload
%                 if any(~suc_upload)
%                     ops{2}.success = false;
%                     failStr = sprintf(', %s', sched.Items{~suc_upload});
%                     ops{2}.outcome = sprintf(...
%                         'At least one local path failed to upload %s',...
%                         failStr);
%                     return
%                 end
%                 
%                 ops{2}.success = true;
%                 ops{2}.outcome = [];
%                 
%             end
%             
%         end
%         
%         function [suc, ops, md, guid] = UploadExternalData(obj, md,...
%                 type, path_data)
%         % uploads a single external file to the database, and updates
%         % associated metadata with the path
%         
%             guid = md.GUID;
%         
%             % check that metadata exists in the database (cannnot upload
%             % external data if not - needs to be ingested first)
%             if isempty(obj.GetMetadata('GUID', guid))
%                 error('Metadata not found for GUID: %s - must ingest first.',...
%                     guid)
%             end
%             
%             % check type
%             if ~ischar(type) || ~isvector(type)
%                 error('''type'' must be char.')
%             end
%             
%             % check input path
%             if ~ischar(path_data) || ~exist(path_data, 'file')
%                 error('File not found: %s', path_data)
%             end
%             
%             % copy
%             ops = {};
%             [ops, md] = obj.copyToFilesystem(path_data, type, guid, ops, md);
%             suc = ops{1}.success;
%             
%             % update metadata
%             obj.ReplaceMetadata(md);
%             
%         end
%         
%         function [suc, ops, md, guid] = UploadVariable(obj, md, type, var)
%         % rather than copying a data file into the DB file system (a la
%         % UploadExternalData) this method uploads a variable in memory
%         % by writing it directly into the file system and updating the
%         % associated metadata object with the new path. For now this just
%         % copies the variable to a temp file then calls UploadExternalData.
%         % todo - make this save directly to the FS
%         
%             guid = md.GUID;
%             path_temp = fullfile(tempdir, sprintf('%s_%s.mat', type, guid));
%             data = var;
%             save(path_temp, 'data');
%             [suc, ops, md, guid] = obj.UploadExternalData(md, type, path_temp);
% 
%         end
%         
%         function [suc, err] = ReplaceMetadata(obj, md)
%         % this is just a wrapper for .ServerUpdate, using a slightly more
%         % friendly name (for users who aren't thinking about whether
%         % they're updating a server or not, and are instead just thinking
%         % that they're updating metadata)
%         
%             [suc, err] = obj.ServerUpdate(md);
%             obj.updateUITable;
%             
%         end
%         
%         function ConnectToServer(obj, ip_server, port_server, path_database)
%         % connects to a tepAnalysisServer instance over TCP/IP
%         
%             % if a path to a DB was supplied, validate it
%             if exist('path_database', 'var') && ~isempty(path_database)
%                 obj.validateDatabasePath(path_database);
%             else
%                 path_database = [];
%             end
%         
%             % attempt connection
%             teEcho('Connecting to remote server on %s:%d...\n', ip_server,...
%                 port_server);
%             res = pnet('tcpconnect', ip_server, port_server);
%             
%             % process result
%             if res == -1
%                 error('Could not connect to server.')
%             else
%                 
%                 % set read timeout to 10s
%                 pnet(obj.prConn, 'setreadtimeout', obj.CONST_ReadTimeout)
%                 
%                 % store connection handle, update status
%                 obj.prConn = res;
%                 teEcho('Connected to server %s on port %d.\n', ip_server,...
%                     port_server);
%                 
%                 % authenticate with MAC address
%                 try
%                     mac_local = getMacAddress;
%                     obj.netAwaitReady(res);
%                     obj.NetSendVar(res, mac_local);
%                     obj.netAwaitReady(res);
%                 catch ERR_auth
%                     if isequal(ERR_auth.message, 'Remote error: Access denied.')
%                         teEcho('You need to register your computer on the server with its\nMAC address, which is:%s',...
%                             mac_local);
%                     else
%                         rethrow(ERR_auth)
%                     end
%                     return
%                 end
%                 
%                 obj.Status = 'connected';
%                 obj.prConnectedToServer = true;
%                 
%                 % send username 
%                 obj.NetSendCommand(obj.prConn, sprintf('USER %s\n', obj.User));
%                 
%                 % get metadata from server
%                 obj.NetSendCommand(obj.prConn, 'GET Metadata');
%                 obj.md = obj.NetReceiveVar(obj.prConn);
%                 
%                 % get backup database path
%                 obj.NetSendCommand(obj.prConn, 'GET Path_Backup');
%                 obj.prPath_Backup = obj.NetReceiveVar(obj.prConn);
%                 
%                 % get paths from server if not supplied as input arg
%                 if isempty(path_database)
%                     obj.NetSendCommand(obj.prConn, 'GET Path_Database');
%                     path_database = obj.NetReceiveVar(obj.prConn);
%                     obj.validateDatabasePath(path_database);
%                 end
%                 
%             end
%             
%         end
%         
%         function DisconnectFromServer(obj)
%             if obj.prConnectedToServer
%                 pnet(obj.prConn, 'close');
%                 teEcho('Disconnected from server.\n');
%             end
%             obj.prConnectedToServer = false;
%             obj.Status = 'not connected';
%         end
%         
%         function [suc, err] = ServerIngest(obj, md)
%         % sends newly-ingested metadata to the server
%         
%             suc = false;
%             err = 'unknown error';
%             
%             if ~obj.prConnectedToServer
%                 error('Not connected to server.')
%             end
%             
%             % tell sever to expect metadata update
%             obj.NetSendCommand(obj.prConn, 'INGEST');
%             
%             % send new metadata chunk
%             obj.NetSendVar(obj.prConn, md)
%             
%             % await validity code
%             suc = obj.NetReceiveVar(obj.prConn);
%             
%             % if error, get error message
%             if ~suc
%                 err = obj.NetReceiveVar(obj.prConn);
%                 return
%             else
%                 obj.AddLog('Sent metadata for GUID %s to server\n', md.GUID);
%                 err = '';
%             end
%             
%         end
%         
%         function [suc, err] = ServerUpdate(obj, md)
%         % updates existing metadata on the server
%         
%             suc = false;
%             err = 'unknown error';
%             
%             if ~obj.prConnectedToServer
%                 error('Not connected to server.')
%             end
%             
%             % tell sever to expect metadata update
%             obj.NetSendCommand(obj.prConn, 'UPDATE');
%             
%             % send new metadata chunk
%             obj.NetSendVar(obj.prConn, md)
%             
%             % await validity code
%             suc = obj.NetReceiveVar(obj.prConn);
%             
%             % if error, get error message
%             if ~suc
%                 err = obj.NetReceiveVar(obj.prConn);
%                 return
%             end
%             
%             obj.updateUITable
%             
%             obj.AddLog('Updated metadata for GUID %s on server\n', md.GUID);
%             suc = true;
%             err = '';
%             
%         end
%                 
%         function guid = GetGUID(obj, varargin)
%             
%             guid = [];
%             
%             cmd = 'GET GetGUID ';
%             guid = obj.netExecuteQueryFromPairs(cmd, varargin{:});
%             if iscell(guid) && length(guid) == 1
%                 guid = guid{1};
%             end
%             
%         end
%         
%         function [md, guid] = GetMetadata(obj, varargin)
%             
%             md = [];
%             guid = [];
%             
%             cmd = 'GET GetMetadata ';
%             res = obj.netExecuteQueryFromPairs(cmd, varargin{:});
%             if iscell(res) && numel(res) == 2
%                 md = res{1};
%                 guid = res{2};
%             end
%             
%             if ~isempty(md)
%                 if iscell(md)
%                     cellfun(@(x) x.ResetCache, md)
%                 elseif isa(md, 'teMetadata')
%                     md.ResetCache;
%                 end
%             end
%         end
%         
%         function [val, guid] = GetPath(obj, type, varargin)
%             
%             val = [];
%             guid = [];
%             
%             cmd = sprintf('GET GetPath ''%s''', type);
%             res = obj.netExecuteQueryFromPairs(cmd, varargin{:});
%             if iscell(res) && numel(res) == 2
%                 val = res{1};
%                 guid = res{2};
%             end
%             
%         end
%         
%         function [val, guid] = GetField(obj, field, varargin)
%             
%             val = [];
%             guid = [];
%             
%             cmd = sprintf('GET GetField ''%s''', field);
%             res = obj.netExecuteQueryFromPairs(cmd, varargin{:});
%             if iscell(res) && numel(res) == 2
%                 val = res{1};
%                 guid = res{2};
%             end
%              
%         end
%         
%         function [data, guid] = GetVariable(obj, field, varargin)
%         % queries the database and attempts to load, and return, the actual
%         % data (as opposed to just its path). Only works for supported
%         % filetypes - essentially, those that can be loaded into Matlab -
%         % so .mat, .csv, .xlsx, .txt.
%         
%             % get paths and guids. Note that since we call GetPath, we are
%             % getting an absolute path (not a locater path)
%             [pth, guid] = obj.GetPath(field, varargin{:});
%             if isempty(pth), data = []; return, end
%             
%         % check file type. if multple records were returned, we need to
%         % do this for each path, so we use cellfun and place scalar
%         % records into a cell array first 
%         
%             if ~iscell(pth), pth = {pth}; end
%         
%             % note empty records
%             empty = cellfun(@isempty, pth);
%             if all(empty), data = []; return, end
%         
%             % determine file types by extension
%             ext = cell(size(pth));
%             [~, ~, ext(~empty)] = cellfun(@fileparts, pth(~empty), 'uniform', false);
%             
%             % compare to loadable file types
%             isLoadable = false(size(pth));
%             isLoadable(~empty) = ismember(ext(~empty),...
%                 obj.CONST_LoadableFiletypes(:, 1));
%             
%             % load where possible
%             data = cell(size(ext));
%             teEcho('Loading %d variables from file system...\n',...
%                 length(data));
%             loadableFileTypes = obj.CONST_LoadableFiletypes;
%             for d = 1:length(data)
%                 
%                 if ~empty(d) && isLoadable(d)
%                     
%                     % lookup load function for this file type
%                     loadIdx     =...
%                         strcmpi(ext{d}, loadableFileTypes(:, 1));
%                     loadFun     =...
%                         str2func(loadableFileTypes{loadIdx, 2});
%                     
%                     % build the path to the data
%                     path_data = pth{d};
%                     
%                     % load the data
%                     tmp = feval(loadFun, path_data);
%                     
%                     % remove the data from the struct it was loaded into.
%                     % Note that this assumes a struct with a single field
%                     % (or at least it only takes the first field)
%                     if isstruct(tmp)
%                         fnames = fieldnames(tmp);
%                         data{d} = tmp.(fnames{1});
%                     else
%                         % if not a struct, just take the data
%                         data{d} = tmp;
%                     end
%                     
%                 end
%                 
%                 if mod(d, 10) == 0
%                     teEcho('\tLoaded %d of %d...\n', d, length(data));
%                 end
%                 
%             end
%             
%             % if only a single dataset, break out from cell array
%             if numel(data) == 1
%                 data = data{1};
%             end
%             
%         end
%         
%         function tab = GetTable(obj, varargin)
%             
%             tab = [];
%             guid = [];
%             
%             cmd = 'GET GetTable ';
%             tab = obj.netExecuteQueryFromPairs(cmd, varargin{:});
% 
%         end   
%         
%         function h = uitable(obj, varargin)
%             h = table2uitable(obj.Table, varargin{:});
%             obj.h_uitable = h;
%         end
%         
% %         function smry = SummariseChecks(obj, varargin)
% %             
% %             md = obj.GetMetadata(varargin{:});
% %             s = cell(length(md), 1);
% %             for m = 1:length(md)
% %                 s{m} = struct(md(m).Checks);
% %             end
% %             
% %         end
%         
%         % get / set
%         function val = get.Metadata(obj)
%             if ~obj.prConnectedToServer
%                 val = [];
%             else
%                 if ~isempty(obj.HoldQuery)
%                     res = obj.netExecuteQueryFromPairs('GET GetMetadata');
%                     val = res{1};
%                 else
%                     obj.NetSendCommand(obj.prConn, 'GET Metadata');
%                     val = obj.NetReceiveVar(obj.prConn);
%                 end
%             end
%         end
%         
%         function set.HoldQuery(obj, val)
%             if isempty(val)
%                 obj.HoldQuery = [];
%             elseif ~iscell(val) || ~isvector(val)
%                 error('HoldQuery must be a cell array of input arguments.')
%             else
%                 obj.HoldQuery = val;
%             end
%             obj.updateUITable;
%         end
%         
%         function set.Status(obj, val)
%             obj.Status = val;
%             notify(obj, 'StatusChanged')
%         end
%                 
%     end
%     
%     methods (Hidden)
%         
%         function SetUITableSelection(obj, row)
% %             % temp disable table to disable cell change callback
% %             obj.h_uitable.Enable = 'off';
% %             % temp disable selection change callback
% %             oCallBack = obj.h_uitable.CellSelectionCallback;
% %             obj.h_uitable.CellSelectionCallback = '';
% 
% %             % tag table as updating
% %             obj.h_uitable.UserData = 'updating';
% 
%             % use java to update selection
%             jUIScrollPane = findjobj(obj.h_uitable);
%             jUITable = jUIScrollPane.getViewport.getView;
%             jUITable.changeSelection(row-1, 0, false, false);   
% %             
% %             obj.h_uitable.UserData = [];
% %             % renable table
% %             obj.h_uitable.Enable = 'on';
% %             % renable cell selection callback
% %             obj.h_uitable.CellSelectionCallback = oCallBack;
%         end
%         
%     end
%             
%     methods (Access = private)
%         
%         function [ops, md] = copyToFilesystem(obj, path_src, path_locate,...
%                 guid, ops, md)
%             
%             if ~obj.Verbose
%                 obj.AddLog('Copying to filesystem: %s\n', path_src);
%             end
%             
%             % we append operations to the ops cell array - find the current
%             % position
%             oc = length(ops); 
%             oc = oc + 1;
%             
%             % break apart filename and append GUID
%             [~, fil, ext] = fileparts(path_src);
%             file_fs = sprintf('%s_%s_%s', fil, guid, ext);  
% 
%             % make full path to destination - main db
%             path_dest = fullfile(obj.Path_Data, path_locate, file_fs);
% 
%             ops{oc} = struct;
%             [ops{oc}, md] = obj.copyToFilesystemDestination(path_src,...
%                 path_locate, path_dest, file_fs, false, ops{oc}, md);
%             
%             % backup db
%             if ~isempty(obj.Path_Backup)
%                 
%                 % increment operations counter
%                 oc = oc + 1;
%                 ops{oc} = struct;
%                 
%                 % make full path to destination - backup
%                 path_dest = fullfile(obj.Path_Backup_Data, path_locate,...
%                     file_fs);
% 
%                 [ops{oc}, md] = obj.copyToFilesystemDestination(path_src,...
%                     path_locate, path_dest, file_fs, true, ops{oc}, md);
% 
%             end
%             
%         end
%                 
%         function [op, md] = copyToFilesystemDestination(~, path_src,...
%                 path_locate, path_dest, file_fs, isBackup, op, md)
%             
%             % create operation
%             op.operation = 'copy external data';
%             op.path_src = path_src;
%             op.path_dest = path_dest;
%             op.path_fs = fullfile(path_locate, file_fs);
%             op.success = false;
%             op.outcome = 'unknown error';            
%             
%             % check that dest path exists, if not make it
%             [pth, ~, ~] = fileparts(path_dest);
%             tryToMakePath(pth);
% 
%             % copy
%             try
%                 [suc_copy, oc_copy] = copyfile(path_src, path_dest);
%             catch ERR
%                 oc_copy = ERR.message;
%             end       
% 
%             % verify
%             if suc_copy
% 
%                 % ensure file exists in filesystem
%                 suc_exist = exist(path_dest, 'file');
% 
%                 % çompare data and time
%                 d_ext = dir(path_src);
%                 d_fs = dir(path_dest);
%                 suc_compare = isequal(d_ext.bytes, d_fs.bytes);
% %                 suc_compare = isequal(d_ext.bytes, d_fs.bytes) &&...
% %                     isequal(d_ext.datenum, d_fs.datenum);
% 
%             else
% 
%                 % if copy failed, then both verification operations
%                 % must fail, too
%                 suc_exist = false;
%                 suc_compare = false;
% 
%             end                    
% 
%             suc_verify = suc_exist && suc_compare;        
% 
%             % log outcome
%             if ~suc_copy
%                 op.success = false;
%                 op.outcome = oc_copy;
% 
%             elseif suc_copy && ~suc_verify
%                 op.success = false;
%                 op.outcome = 'verification failed';
% 
%             elseif suc_copy && suc_verify
%                 op.success = true;
%                 op.outcome = [];
%                 % store locater path in metadata (unless the isBackup flag
%                 % is set, in which case we don't update the metadata)
%                 if ~isBackup
%                     md.Paths(path_locate) = fullfile(path_locate, file_fs);
%                 end
%             end       
%             
%         end
%         
%         function res = netExecuteQueryFromPairs(obj, cmd, varargin)
%             
%             % prepend hold query
%             varargin = [obj.HoldQuery, varargin];
%                 
%             for i = 1:length(varargin)
%                 if ischar(varargin{i})
%                     cmd = [cmd, sprintf(' ''%s''', varargin{i})];
%                 elseif isnumeric(varargin{i}) || islogical(varargin{i})
%                     cmd = [cmd, sprintf(' %d', varargin{i})];
%                 elseif isa(varargin{i}, 'function_handle')
%                     cmd = [cmd, sprintf(' %s', func2str(varargin{i}))];
%                 else
%                     error('Unsupported value format.')
%                 end
%             end
%             teEcho('Sending query...\n');
%             obj.NetSendCommand(obj.prConn, cmd);
%             teEcho('Awaiting response from server...\n');
%             res = obj.NetReceiveVar(obj.prConn);
% 
%         end
%         
%         function updateUITable(obj)
%             
%             if ~isempty(obj.h_uitable) && isvalid(obj.h_uitable)
%                 tab = obj.Table;
%                 obj.h_uitable.Enable = 'off';
%                 obj.h_uitable.Data = table2cell(tab);
%                 obj.h_uitable.ColumnName = tab.Properties.VariableNames;
%                 obj.h_uitable.Enable = 'on';
%             end
%             
%         end
%         
%     end
%         
% end