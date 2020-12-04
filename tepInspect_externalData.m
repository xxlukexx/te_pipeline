function [md, tracker] = tepInspect_externalData(ext, md, tracker)

    teEcho('Inspecting external %s data...\n', ext.Type);

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.tepInspect_externalData.success = false;
        md.tepInspect_externalData.outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    % import external data metadata to metadata
    md.ImportFromExternalData(ext);
    
    % determine format 
    switch ext.Type
        case 'enobio'
            md = tepInspect_enobio(ext, md);
        case 'eyetracking'
            md = tepInspect_eyetracking(ext, md);
        case 'screenrecording'
            md = tepInspect_screenrecording(ext, md);
        case 'fieldtrip'
            [md, tracker] = tepInspect_fieldtrip(ext, md, tracker);
        otherwise
            md.tepInspect_externalData.success = false;
            md.tepInspect_externalData.outcome = sprintf(...
                'Unkown data format: %s', ext.Type);
            return
    end

    md.tepInspect_externalData.success = true;
    md.tepInspect_externalData.outcome = 'success';

end