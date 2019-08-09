function md = tepInspect_fieldtrip(ext, md)

    % if not existing metadata object is passed, create a new one
    if ~exist('md', 'var') || isempty(md)
        md = teMetadata;
    end
    
    % check metadata is correct format
    if ~isa(md, 'teMetadata')
        md.Checks.tepInspect_fieldtrip_success = false;
        md.Checks.tepInspect_fieldtrip_outcome = 'passed metadata was not teMetadata instance.';
        return
    end
    
    if ~exist(ext.Paths('fieldtrip'), 'file')
        md.Checks.tepInspect_fieldtrip_success = false;
        md.Checks.tepInspect_fieldtrip_outcome =...
            sprintf('cannot find fieldtrip file at: %s',...
            ext.Paths('fieldtrip'));
        return
    end
    
    % find first and last timestamp in ft data
    tmp = load(ext.Paths('fieldtrip'));
    md.Checks.fieldtrip_t1 = tmp.ft_data.abstime(1);
    md.Checks.fieldtrip_t2 = tmp.ft_data.abstime(end);
    
    md.Checks.tepInspect_fieldtrip_success = true;
    md.Checks.tepInspect_fieldtrip_outcome = 'success';

end