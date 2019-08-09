function tepPlotDataTimes(md, fig)

    if ~exist('fig', 'var') || ~ishandle(fig)
        figure('ToolBar', 'none')
    end

    if ~iscell(md)
        md = {md};
    end
    
    numSes = length(md);
    allFnames = {};
    allVals = {};
    allSes = [];
    for s = 1:numSes
        tmpFnames = fieldnames(md{s}.Checks);
        tmpVals = cellfun(@(x) md{s}.Checks.(x), tmpFnames, 'UniformOutput', false);
        allFnames = [allFnames; tmpFnames];
        allVals = [allVals; tmpVals];
        allSes = [allSes; repmat(s, length(tmpFnames), 1)];
    end
    
    % signature for sorting
    sig = cellfun(@(x, y) sprintf('%d%s', x, y), num2cell(max(allSes) - allSes),...
        allFnames, 'UniformOutput', false);
    [~, so] = sort(sig);
    allFnames = allFnames(so);
    allVals = allVals(so);
    allSes = allSes(so);
    
    parts = cellfun(@(x) strsplit(x, '_'), allFnames, 'UniformOutput', false);
    allTypes = cellfun(@(x) x{1}, parts, 'UniformOutput', false);
    time = cellfun(@(x) x{2}, parts, 'UniformOutput', false);
    idx_t1 = strcmpi(time, 't1');
    idx_t2 = strcmpi(time, 't2');
    val_t1 = cell2mat(allVals(idx_t1));
    val_t2 = cell2mat(allVals(idx_t2));
    ses = allSes(idx_t1);
    type = allTypes(idx_t1);
    [type_u, ~, type_s] = unique(type);
    [ses_u, ~, ses_s] = unique(ses);
    numSes = length(ses_u);
    numTypes = length(type_u);
    num = sum(idx_t1);
    
    cols = lines(numTypes);
    yr = [0, num];
    xr = [inf, -inf];
    
%     sp = tight_subplot(numSes, 1, 0.01, 0.03);
    fontSize = 10 + round(50 / num);
    
    for n = 1:num
        
        
        t1 = val_t1(n);
        t2 = val_t2(n);
        s = ses(n);
        t = type_s(n);
        
%         set(gcf, 'CurrentAxes', sp(s))

        t1_dt = datetime(t1, 'ConvertFrom', 'posixtime');
        t2_dt = datetime(t2, 'ConvertFrom', 'posixtime');
        t1_str = char(t1_dt);
        t2_str = char(t2_dt);
        dur_str = char(t2_dt - t1_dt);
        type_str = sprintf('%s %0d', type{n}, s);
        t1t2_str = sprintf('(%s - %s)', t1_str, t2_str);
        str = sprintf('%s\n%s\n%s', type_str, dur_str, t1t2_str);
%         str = sprintf('%s%0d Start: %s End: %s Duration: %s',...
%             type{n}, s, t1_str, t2_str, dur_str);

        rectangle('Position', [t1, n - 1, t2 - t1, 1], 'FaceColor', cols(t, :))
%         rectangle('Position', [t1, t - 1, t2 - t1, 1], 'FaceColor', cols(t, :))

%         tb = textBounds(t1t2_str, gca);
%         xl = xlim;
%         tx = t1 + ((t2 - t1) / 2) - ((tb(3) / 2) * diff(xl));
        tx = t1 + ((t2 - t1) / 2);
        ty = n - 0.5;% - (tb(4) / 2);
        text(tx, ty, str, 'HorizontalAlignment', 'center', 'FontSize', fontSize)
%         
%         tb = textBounds(t1_str, gca);
%         tx = t1 + ((t2 - t1) * .005);
%         ty = t - tb(4) - 0.005;
%         text(tx, ty, t1_str)
%         
%         tb = textBounds(t2_str, gca);
%         tx = t2 - (tb(3) * diff(xl));
%         ty = t - tb(4) - 0.005;
%         text(tx, ty, t2_str)       
        
%         tb = textBounds(dur_str, gca);
%         tx = t1 + ((t2 - t1) / 2) - ((tb(3) / 2) * diff(xl));
%         ty = t - 1 + tb(4) + 0.005;
%         text(tx, ty, dur_str)      
        
      
        
        
        if t1 < xr(1)
            xr(1) = t1;
        end
        if t2 > xr(2)
            xr(2) = t2;
        end
        
        box('off')

        hold on  
        set(gca, 'Visible', 'off')
    end
    
%     for i = 1:length(sp)
%         xlim(sp(i), xr)
%         ylim(sp(i), yr)
%     end
    
%     for s = 1:numSes
%     
%         % find checks with _t1/t2 fields
%         idx = allSes == s;
%         vals = allVals(idx);
%         
% %         fnames = fieldnames(md{s}.Checks);
%         idx_t1 = idx & instr(allFnames, '_t1');
%         idx_t2 = idx & instr(allFnames, '_t2');
%         fnames = allFnames(idx_t1 | idx_t2);
% 
%         % extract type and wheter field is t1/t2
%         parts = cellfun(@(x) strsplit(x, '_'), fnames, 'UniformOutput', false);
%         type = cellfun(@(x) x{1}, parts, 'UniformOutput', false);
%         time = cellfun(@(x) x{2}, parts, 'UniformOutput', false);
%         idx_t1 = strcmpi(time, 't1');
%         idx_t2 = strcmpi(time, 't2');
% 
%         [type_u, ~, type_s] = unique(type);
%         numTypes = length(type_u);
%         cols = lines(numTypes);
% 
%         for t = 1:numTypes
% 
%             idx1 = type_s == t & idx_t1;
%             if sum(idx1) > 1
%                 error('More than one _t1 variable for type %s', type_u{t})
%             elseif ~any(idx1)
%                 continue
%             end
% 
%             idx2 = type_s == t & idx_t2;
%             if sum(idx2) > 1
%                 error('More than one _t2 variable for type %s', type_u{t})
%             elseif ~any(idx2)
%                 continue
%             end
% 
%             t1 = md{s}.Checks.(fnames{idx1});
%             t2 = md{s}.Checks.(fnames{idx2});
% 
%             t1_dt = datetime(t1, 'ConvertFrom', 'posixtime');
%             t2_dt = datetime(t2, 'ConvertFrom', 'posixtime');
%             t1_str = char(t1_dt);
%             t2_str = char(t2_dt);
%             dur_str = char(t2_dt - t1_dt);
%             str = sprintf('%s%0d\nStart: %s\nEnd: %s\nDuration: %s',...
%                 type_u{t}, s, t1_str, t2_str, dur_str);
% 
%             rectangle('Position', [t1, t - 0.8, t2 - t1, 0.8], 'FaceColor', cols(t, :))
%             text(t1, t - 0.5, str, 'FontSize', 16)
%             
%             hold on
% 
%     %         xtimes = cellfun(@str2double, get(gca, 'XTickLabel'));
%     %         set(gca, 'XTickLabel', datetime(xtimes, 'ConvertFrom', 'posixtime'))
% 
% 
%         end
%         
%     end






end