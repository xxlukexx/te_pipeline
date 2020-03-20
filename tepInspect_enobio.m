function md = tepInspect_enobio(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_enobio.success = false;
        md.tepInspect_enobio.outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    % convert to fieldtrip
    path_ft = fullfile(md.LocalSessionFolder, 'fieldtrip');
    if ~exist(path_ft, 'dir')
        
        teEcho('Converting enobio data to fieldtrip...\n');

        try
            % convert to ft in memory
            [ft_data, ft_events, ft_t] =...
                eegEnobio2Fieldtrip(ext.Paths('enobio_easy'));

            % save
            path_ft = fullfile(md.LocalSessionFolder, 'fieldtrip');
            tryToMakePath(path_ft);
            if ismember('sessionstarttime', properties(md))
                sesTime = datestr(md.sessionstarttime, 30);
            else
                sesTime = 'unknown_session_time';
            end
            if ismember('ID', properties(md))
                id = md.ID;
            else
                id = 'unknown_id';
            end
            file_ft = fullfile(path_ft, sprintf('%s_%s_fieldtrip_raw.mat',...
                sesTime, id));
            save(file_ft, 'ft_data')

            % create external data from fieldtrip data
            ft_ext = teExternalData_Fieldtrip(path_ft);
            md = tepInspect_externalData(ft_ext, md);
%             md.ImportFromExternalData(ext)
%             
%             % inspect ft data
%             md = tepInspect_fieldtrip(ft_ext, md);

            e2f_suc = true;
            e2f_oc = 'success';

        catch ERR
            e2f_oc = ERR.message;
            e2f_suc = false;

        end

        md.enobio2fieldtrip.success = e2f_suc;
        md.enobio2fieldtrip.outcome = e2f_oc;
        
    end
    
    md.tepInspect_enobio.success = true;
    md.tepInspect_enobio.outcome = 'success';

end