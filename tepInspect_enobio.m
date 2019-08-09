function md = tepInspect_enobio(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.Checks.tepInspect_enobio_success = false;
        md.Checks.tepInspect_enobio_outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    % convert to fieldtrip
    path_ft = fullfile(md.Paths('session_folder'), 'fieldtrip');
    if ~exist(path_ft, 'dir')

        try
            % convert to ft in memory
            [ft_data, ft_events, ft_t] =...
                eegEnobio2Fieldtrip(ext.Paths('enobio_easy'));
            ft_data.events = ft_events;
            ft_data.abstime = ft_t;
            ft_data.samplerate = ext.SampleRate;

            % save
            path_ft = fullfile(md.Paths('session_folder'), 'fieldtrip');
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

            % inspect fieldtrip data
            md.ImportFromExternalData(ft_ext);
            md.Checks.fieldtrip_t1 = ft_data.abstime(1);
            md.Checks.fieldtrip_t2 = ft_data.abstime(end);

            e2f_suc = true;
            e2f_oc = 'success';

        catch ERR
            e2f_oc = ERR.message;
            e2f_suc = false;

        end

        md.Checks.enobio2fieldtrip_success = e2f_suc;
        md.Checks.enobio2fieldtrip_outcome = e2f_oc;
        
    end
    
    md.Checks.tepInspect_enobio_success = true;
    md.Checks.tepInspect_enobio_outcome = 'success';

end