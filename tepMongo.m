classdef tepMongo < mongo
    
    properties (SetAccess = private)
        
    end
    
    properties (Dependent, SetAccess = private)
        GridFSBucket
    end
    
    properties (Access = private)
        prGridFSBucket = []
    end
    
    methods
%         
%         function obj = tepMongo(varargin)
%             try
%                 obj = obj@mongo(varargin{:});
%             catch ERR
%                 if contains(ERR.message, '[Mongo Driver Error]:Expected databasename to match one of these values:')
%                     
%             end
%         end
        
        function fileID = UploadFile(obj, path_file, uploadOptions)
        
            if ~obj.isopen
                error('No connection.')
            end
            
            if ~exist(path_file, 'file')
                error('File not found: %s', path_file)
            end
            
            if ~exist('uploadOptions', 'var')
                uploadOptions = struct;
            end
            
            [~, fil, ext] = fileparts(path_file);
            filename = [fil, ext];
%             db = obj.getDBHandle;
            
            % append original path to options
            uploadOptions = catstruct(struct('Path_Original', path_file),...
                uploadOptions);
            
            % convert uploadOptions struct to BSON document
            opt_bson = org.bson.Document;
            opt_bson = opt_bson.parse(jsonencode(uploadOptions));
            opt_gfs = com.mongodb.client.gridfs.model.GridFSUploadOptions;
            opt_gfs.metadata(opt_bson);
            
            % create java upload stream to input file
            uploadStream = java.io.FileInputStream(java.io.File(path_file));

            % upload to mongodb
            fileID = obj.GridFSBucket.uploadFromStream(filename, uploadStream, opt_gfs);
            uploadStream.close;
            
        end
        
        function suc = findOneAndReplace(obj, collection, findQuery, json)
            
            h_db = getDBHandle(obj);
            h_coll = h_db.getCollection(collection);
            mg_query = com.mongodb.util.JSON.parse(findQuery);
            mg_json = com.mongodb.BasicDBObject.parse(json);
            res = h_coll.findOneAndReplace(mg_query, mg_json);
            suc = ~isempty(res);
            
%             opt = com.mongodb.client.model.ReplaceOptions;
% %             opt = jsonencode(struct('upsert', false));
%             
%             opt = com.mongodb.client.model.DBCollectionFindOptions;
%             h_coll.find(mg_query, opt)
        end
        
        function suc = findOneAndUpdate(obj, collection, findQuery, json, opt)
            
            if ~exist('opt', 'var') || isempty(opt)
                opt = com.mongodb.client.model.FindOneAndUpdateOptions;
            end
            
            h_db = getDBHandle(obj);
            h_coll = h_db.getCollection(collection);
            
            json = sprintf('{ $set: %s }', json);
            mg_query = com.mongodb.util.JSON.parse(findQuery);
            mg_json = com.mongodb.BasicDBObject.parse(json);
            res = h_coll.findOneAndUpdate(mg_query, mg_json, opt);
            suc = ~isempty(res);
            
        end
            
%         function path_download = DownloadFile(obj, fileID, path_download)
%             
%             if ~exist('path_download', 'var') || isempty(path_download)
%                 % download to current folder
%                 path_download = pwd;
%             end
%             
%             conn = obj.getConnHandle;
%             conn.ge
%             fi = obj.GridFSBucket.find(com
% %             downloadStream = FileOutputStream
%             
%             
%         end
        
        function CreateGridFSBucket(obj)
            db = obj.getDBHandle; 
            obj.prGridFSBucket =...
                com.mongodb.client.gridfs.GridFSBuckets.create(db);
        end
        
        function val = hasGridFSBucket(obj)
            val = obj.collectionexists('fs.chunks') &&...
                obj.collectionexists('fs.files');
        end
        
        % set/get
        function val = get.GridFSBucket(obj)
            if isempty(obj.prGridFSBucket)
                obj.CreateGridFSBucket
            end
            val = obj.prGridFSBucket;
        end
        
    end
    
end