clf
hold on

mt = sync.match_table;


path_save = '/users/luke/desktop/bttmp/syncplots';
tryToMakePath(path_save);

xlim([0.5, 2.5]);
set(gca, 'ydir', 'reverse')

for i = 1:size(mt, 1)
    
    if ~mt.event_matched
%         scatter(x1, y1, [], 'r')
        continue
    end
    
    x1 = 1;
    x2 = 2;
    y1 = mt.te_time(i);
    y2 = mt.eeg_time(i);
    
%     scatter(x1, y1, [], 'k')
    line([x1, x2], [y1, y2], 'color', 'g')
    if ~isempty(lab_eeg{i})
        t = text(x2 + .2, y1, lab_eeg{i});
        t.FontName = 'menlo';
        t.FontSize = 7;
    end
    
    if mod(i, 50) == 0
        fprintf('%d of %d\n', i, size(mt, 1));
%         drawnow
    end
    
end

scatter(ones(length(time_te), 1), time_te, [], 'k')
scatter(repmat(2, length(time_eeg), 1), time_eeg, [], 'b')

y = mt.eeg_time(~mt.event_matched);
x = repmat(2, length(y), 1);
scatter(x, y, [], 'r')

fprintf('Exporting...\n')
fig = gcf;
fig.Visible = 'off';
fig.Position(4) = 20000;
exportgraphics(gca, fullfile(path_save, 'sync.png'))
fprintf('done')


%%


for i = 1:length(lab_te)
    x = 1;
    y = time_te(i) - time_te(1);
    scatter(x - .2, y)
    text(x + .2, y, lab_te{i})
end