function tepAnalysisDB2Mongo(path_db, mongo_name)

    % read tep DB
    path_md = fullfile(path_db, 'metadata.mat');
    path_data = fullfile(path_db, 'data');
    load(path_md)
    num = length(md);
    
    % create mongo connection
    mg = tepMongo('127.0.0.1', 27017, mongo_name);
    
    if ~mg.collectionexists('metadata')
        mg.createCollection('metadata');
    end
%     num = 10;
    for i = 1:num
        
        fprintf('Metadata %d of %d: %s\n', i, num, md{i}.GUID)
        
        % convert metadata to struct
        st = md{i}.StructTree;
        
        % remove paths collection
        st = rmfield(st, 'Paths');
        
        % make field names lowercase
        st = structFieldsToLowercase(st);        

        % loop through files
        fileID = cell(md{i}.Paths.Count, 1);
        for p = 1:md{i}.Paths.Count
            
            % get path in old fs
            path_file = fullfile(path_data, md{i}.Paths(p));
            
            % add parent object ID, session GUID and file type key
            opt = struct(...
                'parent', md{i}.GUID,...
                'key', md{i}.Paths.Keys{p},...
                'path_original', path_file);
            
            % upload to GridFS
            fileID{p} = mg.UploadFile(path_file, opt);
            
            % store reference in metadata
            st.externaldata.(md{i}.Paths.Keys{p}) = fileID{p};
            
            fprintf('\tFile %d of %d: %s\n', p, md{i}.Paths.Count,...
                md{i}.Paths.Keys{p})
                
        end

        % upload to mongo
        st_json = lm_prejsonencode(st);
        st_json = jsonencode(st_json);
        st_json(end) = [];      % remove closing }
        st_json = sprintf('%s,"_id":"%s"}', st_json, md{i}.GUID);
        mg.insert('metadata', st_json);

    end

end