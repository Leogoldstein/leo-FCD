function plot_duration_per_cell_boxplot(dur_non, dur_ele, folder_name, output_path)

dur_non = dur_non(~isnan(dur_non));
dur_ele = dur_ele(~isnan(dur_ele));

if isempty(dur_non) && isempty(dur_ele)
    return;
end

pos_non = -0.2;
pos_ele =  0.2;

data  = [dur_non; dur_ele];
group = [ones(size(dur_non)); 2*ones(size(dur_ele))];

folder_name = to_scalar_text(folder_name);

fig = figure('Name', "Mean duration per cell - " + folder_name, 'Color','w');
hold on;

boxplot(data, group, 'Positions', [pos_non pos_ele], ...
    'Labels', {'Non-electroporated','Electroporated'}, ...
    'Colors', 'k');

scatter(pos_non + randn(size(dur_non))*0.02, dur_non, 30, [0 0.7 0], 'filled');
scatter(pos_ele + randn(size(dur_ele))*0.02, dur_ele, 30, [0 0 1], 'filled');

ylabel('Mean transient duration per cell (sec)');
title("Mean transient duration per cell - " + folder_name, 'Interpreter','none');
xlim([-0.5 0.5]);
grid on; box on;
hold off;

% --- Sauvegarde ---
if exist('output_path','var') && ~isempty(output_path)
    if ~exist(output_path,'dir'), mkdir(output_path); end
    fname = "duration_" + sanitize_filename(folder_name) + ".png";
    saveas(fig, fullfile(output_path, fname));
end

close(fig);
end

% ---------------- utilities ----------------

function s = to_scalar_text(x)
    if isempty(x), s = ""; return; end

    if iscell(x)
        idx = find(~cellfun(@isempty, x), 1, 'first');
        if isempty(idx), s = ""; else, s = string(x{idx}); end
        return;
    end

    if isstring(x), s = x(1); return; end
    if ischar(x),   s = string(x); return; end

    try
        s = string(x);
        if numel(s) > 1, s = s(1); end
    catch
        s = "";
    end
end

function out = sanitize_filename(s)
    s = string(s);
    out = regexprep(s, '[<>:"/\\|?*]', '_');
    if strlength(out) == 0
        out = "unnamed";
    end
end
