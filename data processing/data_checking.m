function selected_groups = data_checking(selected_groups, include_blue_cells)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2 || isempty(include_blue_cells)
        include_blue_cells = 0;
    end

    if strcmp(char(include_blue_cells), '1')
        choice = questdlg( ...
            'Quel signal veux-tu vérifier ?', ...
            'Data checking', ...
            'GCaMP only', 'BLUE only', 'COMBINED', 'GCaMP only');

        switch choice
            case 'GCaMP only'
                checking_choice2 = '1';
            case 'BLUE only'
                checking_choice2 = '2';
            case 'COMBINED'
                checking_choice2 = '3';
            otherwise
                return;
        end
    else
        checking_choice2 = '1';
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            animal = selected_groups.(current_type)(k);

            if ~isfield(animal, 'data') || isempty(animal.data)
                fprintf('Skipped %s animal %d: no data\n', current_type, k);
                continue;
            end

            data = animal.data;

            current_animal_group = get_safe_field(animal, 'animal_group', sprintf('Animal_%d', k));
            current_ages_group   = get_safe_field(animal, 'ages', {});
            current_dates_group  = get_dates_from_animal(animal);

            nDates = get_n_dates_for_choice(data, checking_choice2);

            for m = 1:nDates

                date_label = get_label_from_cell(current_dates_group, m, sprintf('Date_%d', m));
                age_label  = get_label_from_cell(current_ages_group,  m, sprintf('Age_%d', m));

                fprintf('\n=== DATA CHECKING — %s — %s ===\n', ...
                    char(string(date_label)), char(string(age_label)));

                nPlanes = get_n_planes_for_choice(data, checking_choice2, m);

                for p = 1:nPlanes

                    [F_plane, DF_plane, Raster_plane, MAct_plane, isort1_raw, ...
                        outline_gcampx_plane, outline_gcampy_plane, ...
                        outline_cellposex_plane, outline_cellposey_plane, ...
                        blue_indices_plane] = ...
                        load_plane_for_checking(data, checking_choice2, m, p);

                    if isempty(DF_plane)
                        fprintf('Date %d plan %d skipped: empty DF\n', m, p);
                        continue;
                    end

                    if isempty(F_plane)
                        F_plane = DF_plane;
                    end

                    if isempty(Raster_plane)
                        Raster_plane = zeros(size(DF_plane));
                    end

                    valid_neurons_local = any(~isnan(DF_plane), 2);

                    DF = DF_plane(valid_neurons_local, :);
                    DF(isnan(DF)) = 0;

                    F = F_plane(valid_neurons_local, :);
                    F(isnan(F)) = 0;

                    Raster = Raster_plane(valid_neurons_local, :);
                    Raster(isnan(Raster)) = 0;

                    valid_local_indices = find(valid_neurons_local);

                    if isempty(valid_local_indices)
                        continue;
                    end

                    isort1_plane = prepare_isort1(isort1_raw, valid_local_indices, size(DF_plane, 1));

                    if isempty(isort1_plane)
                        continue;
                    end

                    if strcmp(checking_choice2, '2')
                        batch_size = 10;
                    else
                        batch_size = 30;
                    end

                    num_batches = ceil(numel(isort1_plane) / batch_size);
                    num_columns = size(DF, 2);

                    MAct = MAct_plane;

                    if isempty(MAct)
                        MAct = sum(Raster > 0, 1);
                    end

                    MAct = MAct(:).';

                    if numel(MAct) < num_columns
                        MAct = [MAct zeros(1, num_columns - numel(MAct))];
                    elseif numel(MAct) > num_columns
                        MAct = MAct(1:num_columns);
                    end

                    deviation_plane = get_motion_deviation(data, m);

                    if isempty(deviation_plane)
                        deviation_plane = nan(1, num_columns);
                    end

                    deviation_plane = deviation_plane(:).';

                    if numel(deviation_plane) < num_columns
                        deviation_plane = [deviation_plane nan(1, num_columns - numel(deviation_plane))];
                    elseif numel(deviation_plane) > num_columns
                        deviation_plane = deviation_plane(1:num_columns);
                    end

                    focus_segs = get_motion_focus_segs(data, m);

                    main_fig = figure('Name', sprintf('Data checking – Plan %d', p));
                    screen_size = get(0, 'ScreenSize');
                    set(main_fig, 'Position', screen_size);
                    set(main_fig, 'CloseRequestFcn', @(src,evt) close_data_checking(src));

                    ax1 = subplot('Position', [0.08, 0.75, 0.88, 0.17]);
                    ax2 = subplot('Position', [0.08, 0.43, 0.88, 0.25]);
                    ax3 = subplot('Position', [0.08, 0.27, 0.88, 0.09]);
                    ax4 = subplot('Position', [0.08, 0.11, 0.88, 0.09]);

                    NCell = size(DF, 1);

                    plot(ax3, deviation_plane, 'k', 'LineWidth', 1);
                    ylabel(ax3, 'Deviation');
                    title(ax3, 'Motion deviation');
                    xlim(ax3, [1 num_columns]);
                    grid(ax3, 'on');

                    plot(ax4, MAct, 'LineWidth', 2);
                    xlabel(ax4, 'Frame');
                    ylabel(ax4, 'Active cells');
                    title(ax4, sprintf('Network activity – Plan %d', p));
                    xlim(ax4, [1 num_columns]);
                    grid(ax4, 'on');

                    batch_slider = uicontrol('Parent', main_fig, ...
                        'Style', 'slider', ...
                        'Min', 1, ...
                        'Max', num_batches, ...
                        'Value', 1, ...
                        'SliderStep', [1/max(num_batches-1,1), 1/max(num_batches-1,1)], ...
                        'Units', 'normalized', ...
                        'Position', [0.08 0.235 0.88 0.025]);

                    frame_slider = uicontrol('Parent', main_fig, ...
                        'Style', 'slider', ...
                        'Min', 1, ...
                        'Max', num_columns, ...
                        'Value', 1, ...
                        'SliderStep', [1/max(num_columns-1,1), 100/max(num_columns-1,1)], ...
                        'Units', 'normalized', ...
                        'Position', [0.08 0.205 0.88 0.025]);

                    uicontrol('Parent', main_fig, 'Style', 'pushbutton', ...
                        'String', 'Play focus change', ...
                        'Units', 'normalized', ...
                        'Position', [0.08, 0.01, 0.18, 0.05], ...
                        'Callback', @(~,~) play_focus_change(main_fig, 'next'));

                    uicontrol('Parent', main_fig, 'Style', 'pushbutton', ...
                        'String', 'Replay', ...
                        'Units', 'normalized', ...
                        'Position', [0.28, 0.01, 0.12, 0.05], ...
                        'Callback', @(~,~) play_focus_change(main_fig, 'replay'));

                    uicontrol('Parent', main_fig, 'Style', 'pushbutton', ...
                        'String', 'Next', ...
                        'Units', 'normalized', ...
                        'Position', [0.42, 0.01, 0.10, 0.05], ...
                        'Callback', @(~,~) next_focus_seg(main_fig));

                    setappdata(main_fig, 'DF', DF);
                    setappdata(main_fig, 'F', F);
                    setappdata(main_fig, 'isort1', isort1_plane);
                    setappdata(main_fig, 'batch_size', batch_size);
                    setappdata(main_fig, 'num_columns', num_columns);
                    setappdata(main_fig, 'ax1', ax1);
                    setappdata(main_fig, 'ax2', ax2);
                    setappdata(main_fig, 'ax3', ax3);
                    setappdata(main_fig, 'ax4', ax4);
                    setappdata(main_fig, 'deviation_plane', deviation_plane);
                    setappdata(main_fig, 'focus_segs', focus_segs);
                    setappdata(main_fig, 'last_focus_seg_idx', []);
                    setappdata(main_fig, 'focus_pre_margin_frames', 100);
                    setappdata(main_fig, 'focus_post_margin_frames', 100);
                    setappdata(main_fig, 'focus_play_pause_sec', 0.35);
                    setappdata(main_fig, 'MAct', MAct);
                    setappdata(main_fig, 'NCell', NCell);
                    setappdata(main_fig, 'valid_neuron_indices', valid_local_indices);
                    setappdata(main_fig, 'neurons_in_batch', []);
                    setappdata(main_fig, 'frame_slider', frame_slider);
                    setappdata(main_fig, 'current_frame', 1);
                    setappdata(main_fig, 'frame_cursor_handles', []);
                    setappdata(main_fig, 'checking_choice2', checking_choice2);
                    setappdata(main_fig, 'selected_cells_movie', []);
                    setappdata(main_fig, 'movie_outline_handles', []);
                    setappdata(main_fig, 'outline_gcampx', outline_gcampx_plane);
                    setappdata(main_fig, 'outline_gcampy', outline_gcampy_plane);
                    setappdata(main_fig, 'outline_cellposex', outline_cellposex_plane);
                    setappdata(main_fig, 'outline_cellposey', outline_cellposey_plane);
                    setappdata(main_fig, 'blue_indices', blue_indices_plane);

                    fprintf('DEBUG combined outlines: nOutlines=%d | nBlueIdx=%d\n', ...
                        numel(outline_gcampx_plane), numel(blue_indices_plane));
                    
                    if ~isempty(blue_indices_plane)
                        disp(blue_indices_plane(:).');
                    end

                    movie_data = open_movie_for_animal(animal, m, p);
                    setappdata(main_fig, 'movie_data', movie_data);

                    batch_slider.Callback = @(src, ~) update_batch_display( ...
                        batch_slider, DF, isort1_plane, batch_size, ...
                        num_columns, ax1, ax2, main_fig);

                    frame_slider.Callback = @(src, ~) update_frame_cursor_and_movie( ...
                        main_fig, round(get(src, 'Value')));

                    frame_listener = addlistener(frame_slider, 'ContinuousValueChange', ...
                        @(src, ~) update_frame_cursor_and_movie(main_fig, round(get(src, 'Value'))));
                    setappdata(main_fig, 'frame_slider_listener', frame_listener);

                    try
                        frame_slider.ValueChangedFcn = @(src, ~) update_frame_cursor_and_movie( ...
                            main_fig, round(get(src, 'Value')));
                    catch
                    end

                    linkaxes([ax1, ax2, ax3, ax4], 'x');

                    sgtitle(main_fig, ...
                        sprintf('%s – %s – %s – Plan %d', ...
                        char(string(current_animal_group)), ...
                        char(string(date_label)), ...
                        char(string(age_label)), p), ...
                        'FontWeight', 'bold');

                    update_batch_display(batch_slider, DF, isort1_plane, ...
                        batch_size, num_columns, ax1, ax2, main_fig);

                    update_frame_cursor_and_movie(main_fig, 1);

                    uiwait(main_fig);
                end
            end
        end
    end
end

function movie_data = open_movie_for_animal(animal, m, p)

    movie_data = [];

    if ~isfield(animal, 'paths') || ...
            ~isfield(animal.paths, 'suite2p') || ...
            isempty(animal.paths.suite2p)
        fprintf('No paths.suite2p found.\n');
        return;
    end

    current_suite2p_group = animal.paths.suite2p;

    if size(current_suite2p_group,1) < m || isempty(current_suite2p_group{m,1})
        fprintf('No suite2p path for date %d.\n', m);
        return;
    end
    
    planes_cell = current_suite2p_group{m,1};
    
    if ~iscell(planes_cell) || numel(planes_cell) < p || isempty(planes_cell{p})
        fprintf('No suite2p path for date %d plane %d.\n', m, p);
        return;
    end
    
    current_suite2p_path = planes_cell{p};
    
    while iscell(current_suite2p_path)
        current_suite2p_path = current_suite2p_path{1};
    end
    
    current_suite2p_path = char(string(current_suite2p_path));

    reg_tif_dir = fullfile(current_suite2p_path, 'reg_tif');

    if ~isfolder(reg_tif_dir)
        fprintf('reg_tif folder not found:\n%s\n', reg_tif_dir);
        return;
    end

    movie_data = open_reg_tif_stack_viewer(reg_tif_dir, p);
end

function movie_data = open_reg_tif_stack_viewer(reg_tif_dir,p)

    movie_data = [];

    reg_tif_dir = char(string(reg_tif_dir));

    files = dir(fullfile(reg_tif_dir,'*.tif'));

    if isempty(files)
        fprintf('No TIFF in %s\n',reg_tif_dir);
        return;
    end

    numbers = nan(numel(files),1);

    for k = 1:numel(files)
        tok = regexp(files(k).name,'file(\d+)','tokens','once');

        if isempty(tok)
            numbers(k)=Inf;
        else
            numbers(k)=str2double(tok{1});
        end
    end

    [~,ord] = sort(numbers);
    files = files(ord);

    fullPaths = fullfile(reg_tif_dir,{files.name});

    infos = cell(numel(fullPaths),1);
    pagesPerFile = zeros(numel(fullPaths),1);

    for k = 1:numel(fullPaths)
        infos{k}=imfinfo(fullPaths{k});
        pagesPerFile(k)=numel(infos{k});
    end

    cumulativePages = cumsum(pagesPerFile);
    nFrames = cumulativePages(end);

    I = imread(fullPaths{1},1,'Info',infos{1});
    I = prepare_movie_frame(I);

    movie_fig = figure( ...
        'Name',sprintf('Movie plane %d',p), ...
        'NumberTitle','off');

    ax = axes(movie_fig);
    hImg = imagesc(ax,I);

    axis(ax,'image');
    axis(ax,'off');
    colormap(ax,gray);

    title(ax,sprintf('Frame 1 / %d',nFrames));

    movie_data.fullPaths = fullPaths;
    movie_data.infos = infos;
    movie_data.cumulativePages = cumulativePages;
    movie_data.nFrames = nFrames;
    movie_data.movie_fig = movie_fig;
    movie_data.ax = ax;
    movie_data.hImg = hImg;

    fprintf('Loaded %d frames from %d tif files.\n', ...
        nFrames,numel(fullPaths));
end

function update_movie_stack(main_fig, frame_index)

    if ~isappdata(main_fig, 'movie_data')
        return;
    end

    movie_data = getappdata(main_fig, 'movie_data');

    if isempty(movie_data) || ~isfield(movie_data, 'nFrames')
        return;
    end

    if ~isfield(movie_data, 'movie_fig') || isempty(movie_data.movie_fig) || ~isvalid(movie_data.movie_fig)
        return;
    end

    if ~isfield(movie_data, 'hImg') || isempty(movie_data.hImg) || ~isvalid(movie_data.hImg)
        return;
    end

    frame_index = max(1, min(frame_index, movie_data.nFrames));

    fileIdx = find(movie_data.cumulativePages >= frame_index, 1, 'first');

    if isempty(fileIdx)
        return;
    end

    if fileIdx == 1
        pageIdx = frame_index;
    else
        pageIdx = frame_index - movie_data.cumulativePages(fileIdx - 1);
    end

    try
        I = imread(movie_data.fullPaths{fileIdx}, pageIdx, 'Info', movie_data.infos{fileIdx});
        I = prepare_movie_frame(I);

        set(movie_data.hImg,'CData',I);

        if isfield(movie_data, 'ax') && isvalid(movie_data.ax)
            title(movie_data.ax, sprintf('Frame %d / %d | file %d page %d', ...
                frame_index, movie_data.nFrames, fileIdx, pageIdx));
        end

        update_movie_outlines(main_fig);

        drawnow limitrate;

    catch ME
        warning('Could not read movie frame %d: %s', frame_index, ME.message);
    end
end

function I = prepare_movie_frame(I)

    I = mat2gray(I);

    try
        I = adapthisteq(I, ...
            'NumTiles',[8 8], ...
            'ClipLimit',0.02);
    catch
        I = imadjust(I, stretchlim(I, [0.01 0.995]), []);
    end

    try
        I = medfilt2(I, [5 5]);
    catch
    end
end

function update_movie_outlines(main_fig)

    if ~isvalid(main_fig)
        return;
    end

    if ~isappdata(main_fig, 'movie_data')
        return;
    end

    movie_data = getappdata(main_fig, 'movie_data');

    if isempty(movie_data) || ~isfield(movie_data, 'ax') || ~isvalid(movie_data.ax)
        return;
    end

    old_handles = [];

    if isappdata(main_fig, 'movie_outline_handles')
        old_handles = getappdata(main_fig, 'movie_outline_handles');
    end

    if ~isempty(old_handles)
        for i = 1:numel(old_handles)
            if isvalid(old_handles(i))
                delete(old_handles(i));
            end
        end
    end

    neurons_in_batch = getappdata(main_fig, 'neurons_in_batch');
    valid_neuron_indices = getappdata(main_fig, 'valid_neuron_indices');
    checking_choice2 = getappdata(main_fig, 'checking_choice2');

    outline_gcampx = getappdata(main_fig, 'outline_gcampx');
    outline_gcampy = getappdata(main_fig, 'outline_gcampy');
    outline_cellposex = getappdata(main_fig, 'outline_cellposex');
    outline_cellposey = getappdata(main_fig, 'outline_cellposey');

    blue_indices = [];
    if isappdata(main_fig, 'blue_indices')
        blue_indices = getappdata(main_fig, 'blue_indices');
    end

    selected_cells = getappdata(main_fig, 'selected_cells_movie');

    h = gobjects(0);

    if isempty(neurons_in_batch) || isempty(valid_neuron_indices)
        setappdata(main_fig, 'movie_outline_handles', h);
        return;
    end

    ax = movie_data.ax;
    hold(ax, 'on');

    for i = 1:numel(neurons_in_batch)

        local_idx = neurons_in_batch(i);

        if local_idx > numel(valid_neuron_indices)
            continue;
        end

        original_idx = valid_neuron_indices(local_idx);

        x = [];
        y = [];
        is_blue = false;

        switch checking_choice2

            case '1'
                idx_g = original_idx;

                if ~isempty(outline_gcampx) && idx_g <= numel(outline_gcampx)
                    x = outline_gcampx{idx_g};
                    y = outline_gcampy{idx_g};
                end

            case '2'
                idx_b = original_idx;
                is_blue = true;

                if ~isempty(outline_cellposex) && idx_b <= numel(outline_cellposex)
                    x = outline_cellposex{idx_b};
                    y = outline_cellposey{idx_b};
                end

            case '3'
                idx_c = original_idx;

                if ~isempty(outline_gcampx) && idx_c <= numel(outline_gcampx)
                    x = outline_gcampx{idx_c};
                    y = outline_gcampy{idx_c};
                end

                if ~isempty(blue_indices)
                    is_blue = ismember(idx_c, blue_indices(:));
                end
        end

        if isempty(x) || isempty(y)
            continue;
        end

        if ismember(local_idx, selected_cells)
            col = [1 0 0];
            lw = 2.0;
        elseif is_blue
            col = [0 0.4 1];
            lw = 1.2;
        else
            col = [0 1 0];
            lw = 1.2;
        end

        h(end+1) = plot(ax, x, y, '-', ...
            'Color', col, ...
            'LineWidth', lw, ...
            'HitTest', 'on', ...
            'PickableParts', 'all', ...
            'ButtonDownFcn', @(src,evt) movie_outline_clicked(main_fig, local_idx)); %#ok<AGROW>
    end

    hold(ax, 'off');
    setappdata(main_fig, 'movie_outline_handles', h);
end

function movie_outline_clicked(main_fig, local_idx)

    if ~isvalid(main_fig)
        return;
    end

    click_type = get(gcbf, 'SelectionType');

    selected_cells = [];

    if isappdata(main_fig, 'selected_cells_movie')
        selected_cells = getappdata(main_fig, 'selected_cells_movie');
    end

    if strcmp(click_type, 'normal')

        if ~ismember(local_idx, selected_cells)
            selected_cells(end+1) = local_idx;
        end

    elseif strcmp(click_type, 'alt')

        selected_cells(selected_cells == local_idx) = [];
    end

    setappdata(main_fig, 'selected_cells_movie', selected_cells);

    ax2 = getappdata(main_fig, 'ax2');
    DF = getappdata(main_fig, 'DF');
    neurons_in_batch = getappdata(main_fig, 'neurons_in_batch');
    num_columns = getappdata(main_fig, 'num_columns');

    update_traces_subplot(ax2, DF, neurons_in_batch, num_columns, main_fig);
    update_movie_outlines(main_fig);
end

function [F_plane, DF_plane, Raster_plane, MAct_plane, isort1_plane, ...
          outline_gcampx_plane, outline_gcampy_plane, ...
          outline_cellposex_plane, outline_cellposey_plane, ...
          blue_indices_plane] = ...
          load_plane_for_checking(data, checking_choice2, m, p)

    F_plane = [];
    DF_plane = [];
    Raster_plane = [];
    MAct_plane = [];
    isort1_plane = [];

    outline_gcampx_plane = {};
    outline_gcampy_plane = {};
    outline_cellposex_plane = {};
    outline_cellposey_plane = {};
    blue_indices_plane = [];

    switch checking_choice2

        case '1'
            plane = data.gcamp_plane;

            F_plane      = safe_get_plane(plane, 'F_gcamp_by_plane', m, p);
            DF_plane     = safe_get_plane(plane, 'DF_gcamp_by_plane', m, p);
            Raster_plane = safe_get_plane(plane, 'Raster_gcamp_by_plane', m, p);
            MAct_plane   = safe_get_plane(plane, 'MAct_gcamp_by_plane', m, p);
            isort1_plane = safe_get_plane(plane, 'isort1_gcamp_by_plane', m, p);

            outline_gcampx_plane = safe_get_plane(plane, 'outlines_gcampx_by_plane', m, p);
            outline_gcampy_plane = safe_get_plane(plane, 'outlines_gcampy_by_plane', m, p);

        case '2'
            plane = data.blue_plane;

            F_plane      = safe_get_plane(plane, 'F_blue_by_plane', m, p);
            DF_plane     = safe_get_plane(plane, 'DF_blue_by_plane', m, p);
            Raster_plane = safe_get_plane(plane, 'Raster_blue_by_plane', m, p);
            MAct_plane   = safe_get_plane(plane, 'MAct_blue_by_plane', m, p);
            isort1_plane = safe_get_plane(plane, 'isort1_blue_by_plane', m, p);

            outline_cellposex_plane = safe_get_plane(plane, 'outlines_x_cellpose_by_plane', m, p);
            outline_cellposey_plane = safe_get_plane(plane, 'outlines_y_cellpose_by_plane', m, p);

        case '3'
            plane = data.combined_plane;

            F_plane      = safe_get_plane(plane, 'F_combined_by_plane', m, p);
            DF_plane     = safe_get_plane(plane, 'DF_combined_by_plane', m, p);
            Raster_plane = safe_get_plane(plane, 'Raster_combined_by_plane', m, p);
            MAct_plane   = safe_get_plane(plane, 'MAct_combined_by_plane', m, p);
            isort1_plane = safe_get_plane(plane, 'isort1_combined_by_plane', m, p);

            valid_combined = safe_get_plane(plane, 'valid_combined_cells_by_plane', m, p);

            outline_all_x = safe_get_plane(plane, 'outlines_x_combined_by_plane', m, p);
            outline_all_y = safe_get_plane(plane, 'outlines_y_combined_by_plane', m, p);

            blue_indices_all = safe_get_plane(plane, 'blue_indices_combined_by_plane', m, p);

            if ~isempty(valid_combined) && ~isempty(outline_all_x)

                valid_combined = valid_combined(:);
                valid_combined = valid_combined( ...
                    valid_combined >= 1 & ...
                    valid_combined <= numel(outline_all_x));

                outline_gcampx_plane = outline_all_x(valid_combined);
                outline_gcampy_plane = outline_all_y(valid_combined);

                if ~isempty(blue_indices_all)
                    [tf, loc] = ismember(blue_indices_all(:), valid_combined(:));
                    blue_indices_plane = loc(tf);
                    blue_indices_plane = blue_indices_plane(:);
                else
                    blue_indices_plane = [];
                end

            else

                outline_gcampx_plane = outline_all_x;
                outline_gcampy_plane = outline_all_y;
                blue_indices_plane = blue_indices_all;
            end

            outline_cellposex_plane = {};
            outline_cellposey_plane = {};
    end
end

function value = safe_get_plane(branch, fieldname, m, p)

    value = [];

    if isempty(branch) || ~isfield(branch, fieldname) || isempty(branch.(fieldname))
        return;
    end

    C = branch.(fieldname);

    if ~iscell(C) || numel(C) < m || isempty(C{m})
        return;
    end

    if iscell(C{m})
        if numel(C{m}) >= p && ~isempty(C{m}{p})
            value = C{m}{p};
        end
    else
        if p == 1
            value = C{m};
        end
    end
end

function isort1_plane = prepare_isort1(isort1_raw, valid_local_indices, nCellsOriginal)

    if isempty(isort1_raw)
        isort1_raw = (1:nCellsOriginal).';
    end

    isort1_raw = isort1_raw(:);
    isort1_raw = isort1_raw(ismember(isort1_raw, valid_local_indices));

    [~, isort1_plane] = ismember(isort1_raw, valid_local_indices);

    isort1_plane = isort1_plane(isort1_plane > 0);
    isort1_plane = isort1_plane(:);

    if isempty(isort1_plane)
        isort1_plane = (1:numel(valid_local_indices)).';
    end
end

function update_batch_display(batch_slider, DF, isort1, batch_size, ...
                              num_columns, ax1, ax2, fig_handle)

    if ~isvalid(fig_handle)
        return;
    end

    batch_index = round(get(batch_slider, 'Value'));
    batch_index = max(1, min(batch_index, ceil(numel(isort1) / batch_size)));

    start_idx = (batch_index - 1) * batch_size + 1;
    end_idx   = min(batch_index * batch_size, numel(isort1));

    neurons_in_batch = isort1(start_idx:end_idx);

    setappdata(fig_handle, 'neurons_in_batch', neurons_in_batch);

    update_raster_subplot(ax1, DF, isort1, neurons_in_batch, start_idx, num_columns);
    update_traces_subplot(ax2, DF, neurons_in_batch, num_columns, fig_handle);

    current_frame = getappdata(fig_handle, 'current_frame');
    update_frame_cursor_and_movie(fig_handle, current_frame);
end

function update_raster_subplot(ax1, DF, isort1, neurons_in_batch, start_idx, num_columns)

    cla(ax1);

    DF_z = zscore(DF, [], 2);
    DF_z(isnan(DF_z)) = 0;

    imagesc(ax1, DF_z(isort1, :));

    [minValue, maxValue] = calculate_scaling(DF_z);
    clim(ax1, [minValue, maxValue]);

    colormap(ax1, 'hot');
    axis(ax1, 'tight');

    xlim(ax1, [1 num_columns]);
    ylabel(ax1, 'Neurons');
    xlabel(ax1, 'Frames');
    set(ax1, 'YDir', 'normal');

    ax1.XTick = 0:1000:num_columns;
    ax1.XTickLabel = arrayfun(@num2str, 0:1000:num_columns, 'UniformOutput', false);

    hold(ax1, 'on');
    rectangle(ax1, ...
        'Position', [1, start_idx - 0.5, num_columns, numel(neurons_in_batch)], ...
        'EdgeColor', 'c', ...
        'LineWidth', 1.5);
    hold(ax1, 'off');
end

function update_traces_subplot(ax2, DF, neurons_in_batch, num_columns, fig_handle)

    cla(ax2);
    hold(ax2, 'on');

    selected_cells = [];

    if nargin >= 5 && ~isempty(fig_handle) && isvalid(fig_handle) && ...
            isappdata(fig_handle, 'selected_cells_movie')
        selected_cells = getappdata(fig_handle, 'selected_cells_movie');
    end

    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = {};

    for i = 1:numel(neurons_in_batch)

        cellIndex = neurons_in_batch(i);

        trace = DF(cellIndex, :);
        trace(isnan(trace)) = 0;

        if ismember(cellIndex, selected_cells)
            trace_color = [1 0 0];
            line_width = 1.4;
        else
            trace_color = [0 0 0];
            line_width = 0.6;
        end

        plot(ax2, trace + vertical_offset, ...
            'Color', trace_color, ...
            'LineWidth', line_width);

        amp = max(trace) - min(trace);

        if amp <= 0 || isnan(amp)
            amp = 1;
        end

        yticks_pos(end+1) = vertical_offset + amp/2; %#ok<AGROW>
        yticklabels_list{end+1} = num2str(cellIndex); %#ok<AGROW>

        vertical_offset = vertical_offset + amp * 1.2;
    end

    xlabel(ax2, 'Frame');
    title(ax2, 'Sorted Cell Traces');
    xlim(ax2, [1 num_columns]);
    ax2.YTick = yticks_pos;
    ax2.YTickLabel = yticklabels_list;
    axis(ax2, 'tight');
    grid(ax2, 'on');
    hold(ax2, 'off');
end

function update_frame_cursor_and_movie(fig_handle, frame_idx)

    if ~isvalid(fig_handle)
        return;
    end

    num_columns = getappdata(fig_handle, 'num_columns');
    frame_idx = max(1, min(frame_idx, num_columns));

    setappdata(fig_handle, 'current_frame', frame_idx);

    frame_slider = getappdata(fig_handle, 'frame_slider');

    if ~isempty(frame_slider) && isvalid(frame_slider)
        frame_slider.Value = frame_idx;
    end

    ax1 = getappdata(fig_handle, 'ax1');
    ax2 = getappdata(fig_handle, 'ax2');
    ax3 = getappdata(fig_handle, 'ax3');
    ax4 = getappdata(fig_handle, 'ax4');

    old_handles = getappdata(fig_handle, 'frame_cursor_handles');

    if ~isempty(old_handles)
        for i = 1:numel(old_handles)
            if isvalid(old_handles(i))
                delete(old_handles(i));
            end
        end
    end

    h = gobjects(0);
    axes_list = [ax1 ax2 ax3 ax4];

    for i = 1:numel(axes_list)

        ax = axes_list(i);

        if isempty(ax) || ~isvalid(ax)
            continue;
        end

        yl = ylim(ax);

        hold(ax, 'on');
        h(end+1) = plot(ax, [frame_idx frame_idx], yl, 'r-', 'LineWidth', 1.2); %#ok<AGROW>
        hold(ax, 'off');
    end

    setappdata(fig_handle, 'frame_cursor_handles', h);

    update_movie_stack(fig_handle, frame_idx);
end

function close_data_checking(fig)

    if isappdata(fig, 'movie_data')
        movie_data = getappdata(fig, 'movie_data');

        if ~isempty(movie_data) && isfield(movie_data, 'movie_fig') && ...
                ~isempty(movie_data.movie_fig) && isvalid(movie_data.movie_fig)
            delete(movie_data.movie_fig);
        end
    end

    if ~isempty(fig) && isvalid(fig)
        uiresume(fig);
        delete(fig);
    end
end

function play_focus_change(main_fig, mode)

    if ~isvalid(main_fig)
        return;
    end

    focus_segs = getappdata(main_fig, 'focus_segs');

    if isempty(focus_segs)
        fprintf('No focus segments available.\n');
        return;
    end

    num_columns = getappdata(main_fig, 'num_columns');

    current_frame = getappdata(main_fig, 'current_frame');
    if isempty(current_frame) || ~isfinite(current_frame)
        current_frame = 1;
    end

    pre_margin = getappdata(main_fig, 'focus_pre_margin_frames');
    post_margin = getappdata(main_fig, 'focus_post_margin_frames');
    pause_sec = getappdata(main_fig, 'focus_play_pause_sec');

    if isempty(pre_margin),  pre_margin = 10; end
    if isempty(post_margin), post_margin = 10; end
    if isempty(pause_sec),   pause_sec = 0.35; end

    last_idx = getappdata(main_fig, 'last_focus_seg_idx');

    switch lower(mode)

        case 'next'

            idx = find(focus_segs(:,1) > current_frame, 1, 'first');

            if isempty(idx)
                fprintf('No more focus segments after current cursor position.\n');
                return;
            end

            setappdata(main_fig, 'last_focus_seg_idx', idx);

        case 'replay'

            idx = last_idx;

            if isempty(idx) || ~isfinite(idx) || idx < 1 || idx > size(focus_segs,1)
                fprintf('No focus segment selected.\n');
                return;
            end

        otherwise
            return;
    end

    seg_start = max(1, round(focus_segs(idx,1)));
    seg_end   = min(num_columns, round(focus_segs(idx,2)));

    before_frame = max(1, seg_start - pre_margin);
    after_frame  = min(num_columns, seg_end + post_margin);

    deviation = getappdata(main_fig, 'deviation_plane');

    max_frame = seg_start;

    if ~isempty(deviation) && numel(deviation) >= seg_end
        seg_dev = deviation(seg_start:seg_end);

        if any(isfinite(seg_dev))
            [~, imax] = max(seg_dev);
            max_frame = seg_start + imax - 1;
        end
    end

    update_frame_cursor_and_movie(main_fig, before_frame);
    pause(pause_sec);

    update_frame_cursor_and_movie(main_fig, max_frame);
    pause(pause_sec);

    update_frame_cursor_and_movie(main_fig, after_frame);
end

function next_focus_seg(main_fig)

    if ~isvalid(main_fig)
        return;
    end

    focus_segs = getappdata(main_fig,'focus_segs');

    if isempty(focus_segs)
        return;
    end

    current_frame = getappdata(main_fig, 'current_frame');

    if isempty(current_frame) || ~isfinite(current_frame)
        current_frame = 1;
    end

    idx = find(focus_segs(:,1) > current_frame, 1, 'first');

    if isempty(idx)
        fprintf('Last focus segment reached.\n');
        return;
    end

    setappdata(main_fig,'last_focus_seg_idx',idx);

    frame = max(1, round(focus_segs(idx,1)));

    update_frame_cursor_and_movie(main_fig, frame);
end

function focus_segs = get_motion_focus_segs(data, m)

    focus_segs = [];

    if ~isfield(data, 'motion') || isempty(data.motion)
        return;
    end

    if ~isfield(data.motion, 'focus_segs_group') || isempty(data.motion.focus_segs_group)
        return;
    end

    S = data.motion.focus_segs_group;

    if ~iscell(S) || numel(S) < m || isempty(S{m})
        return;
    end

    focus_segs = S{m};

    while iscell(focus_segs)
        if isempty(focus_segs)
            focus_segs = [];
            return;
        end
        focus_segs = focus_segs{1};
    end

    if isempty(focus_segs)
        return;
    end

    focus_segs = double(focus_segs);

    if size(focus_segs, 2) ~= 2 && size(focus_segs, 1) == 2
        focus_segs = focus_segs.';
    end

    if size(focus_segs, 2) ~= 2
        warning('focus_segs_group{%d} should be Nx2 [start end].', m);
        focus_segs = [];
        return;
    end

    focus_segs = focus_segs(all(isfinite(focus_segs), 2), :);
    focus_segs = round(focus_segs);
end

function nDates = get_n_dates_for_choice(data, checking_choice2)

    nDates = 0;

    switch checking_choice2
        case '1'
            if isfield(data, 'gcamp_plane') && isfield(data.gcamp_plane, 'DF_gcamp_by_plane')
                nDates = numel(data.gcamp_plane.DF_gcamp_by_plane);
            end

        case '2'
            if isfield(data, 'blue_plane') && isfield(data.blue_plane, 'DF_blue_by_plane')
                nDates = numel(data.blue_plane.DF_blue_by_plane);
            end

        case '3'
            if isfield(data, 'combined_plane') && isfield(data.combined_plane, 'DF_combined_by_plane')
                nDates = numel(data.combined_plane.DF_combined_by_plane);
            end
    end
end

function nPlanes = get_n_planes_for_choice(data, checking_choice2, m)

    nPlanes = 0;

    switch checking_choice2
        case '1'
            if isfield(data, 'gcamp_plane') && ...
                    isfield(data.gcamp_plane, 'DF_gcamp_by_plane') && ...
                    numel(data.gcamp_plane.DF_gcamp_by_plane) >= m && ...
                    ~isempty(data.gcamp_plane.DF_gcamp_by_plane{m})
                nPlanes = numel(data.gcamp_plane.DF_gcamp_by_plane{m});
            end

        case '2'
            if isfield(data, 'blue_plane') && ...
                    isfield(data.blue_plane, 'DF_blue_by_plane') && ...
                    numel(data.blue_plane.DF_blue_by_plane) >= m && ...
                    ~isempty(data.blue_plane.DF_blue_by_plane{m})
                nPlanes = numel(data.blue_plane.DF_blue_by_plane{m});
            end

        case '3'
            if isfield(data, 'combined_plane') && ...
                    isfield(data.combined_plane, 'DF_combined_by_plane') && ...
                    numel(data.combined_plane.DF_combined_by_plane) >= m && ...
                    ~isempty(data.combined_plane.DF_combined_by_plane{m})
                nPlanes = numel(data.combined_plane.DF_combined_by_plane{m});
            end
    end
end

function [min_val, max_val] = calculate_scaling(data)

    flattened_data = data(:);
    flattened_data = flattened_data(isfinite(flattened_data));

    if isempty(flattened_data)
        min_val = 0;
        max_val = 1;
        return;
    end

    min_val = prctile(flattened_data, 5);
    max_val = prctile(flattened_data, 99.9);

    if min_val >= max_val
        min_val = min(flattened_data);
        max_val = max(flattened_data);
    end

    if min_val == max_val
        max_val = min_val + eps;
    end
end

function value = get_safe_field(s, fieldname, default_value)

    if isfield(s, fieldname) && ~isempty(s.(fieldname))
        value = s.(fieldname);
    else
        value = default_value;
    end
end

function dates = get_dates_from_animal(animal)

    dates = {};

    if isfield(animal, 'metadata') && ~isempty(animal.metadata)

        metadata = animal.metadata;

        if isstruct(metadata)

            if isfield(metadata, 'DateName')
                dates = {metadata.DateName};
                return;
            elseif isfield(metadata, 'date')
                dates = {metadata.date};
                return;
            end

        elseif istable(metadata)

            if any(strcmp(metadata.Properties.VariableNames, 'DateName'))
                dates = cellstr(string(metadata.DateName));
                return;
            elseif any(strcmp(metadata.Properties.VariableNames, 'date'))
                dates = cellstr(string(metadata.date));
                return;
            end
        end
    end

    if isfield(animal, 'paths') && isfield(animal.paths, 'date')
        dates = animal.paths.date;
    end
end

function label = get_label_from_cell(c, idx, default_label)

    label = default_label;

    if isempty(c)
        label = char(string(default_label));
        return;
    end

    if iscell(c)
        if idx <= numel(c) && ~isempty(c{idx})
            label = c{idx};
        end

    elseif isstring(c)
        if numel(c) >= idx
            label = c(idx);
        else
            label = default_label;
        end

    elseif ischar(c)
        label = c;

    elseif isnumeric(c)
        if idx <= numel(c)
            label = sprintf('P%d', c(idx));
        else
            label = default_label;
        end

    else
        label = default_label;
    end

    if iscell(label)
        if isempty(label)
            label = default_label;
        else
            label = label{1};
        end
    end

    if isnumeric(label)
        label = num2str(label);
    end

    label = char(string(label));
end

function deviation_plane = get_motion_deviation(data, m)

    deviation_plane = [];

    if ~isfield(data, 'motion') || isempty(data.motion)
        return;
    end

    if ~isfield(data.motion, 'deviation_group') || isempty(data.motion.deviation_group)
        return;
    end

    D = data.motion.deviation_group;

    if ~iscell(D) || numel(D) < m || isempty(D{m})
        return;
    end

    deviation_plane = D{m};

    while iscell(deviation_plane)
        if isempty(deviation_plane)
            deviation_plane = [];
            return;
        end
        deviation_plane = deviation_plane{1};
    end

    deviation_plane = double(deviation_plane(:).');
end