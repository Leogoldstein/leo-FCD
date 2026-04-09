function [num_cells_mask, mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_path)

    num_cells_mask = 0;
    mask_cellpose = {};
    props_cellpose = struct('Area', {}, 'Centroid', {});
    outlines_x_cellpose = {};
    outlines_y_cellpose = {};

    try
        % ---------- Import Python ----------
        module_name = 'python_function';
        spec = py.importlib.util.find_spec(module_name);

        if isempty(spec)
            error('Module Python "%s" introuvable.', module_name);
        end

        mod = py.importlib.import_module(module_name);
        image = mod.read_npy_file(npy_file_path);

        keys = image.keys();
        keys_list = cellfun(@char, cell(py.list(keys)), 'UniformOutput', false);

        % ---------- MASQUES ----------
        if ismember('masks', keys_list)
            masks = image{'masks'};
            masks_mat = double(py.numpy.array(masks));
            masks_mat(isnan(masks_mat)) = 0;

            labels = unique(masks_mat);
            labels(labels == 0) = [];
            num_cells_mask = numel(labels);
        else
            error('Clé "masks" absente.');
        end

        % ---------- OUTLINES (robuste) ----------
        outlines_py = [];
        has_outlines = false;

        if ismember('outlines', keys_list)
            try
                outlines_candidate = image{'outlines'};

                if ~isempty(outlines_candidate) && ~isnumeric(outlines_candidate)
                    outlines_py = outlines_candidate;
                    has_outlines = true;
                end
            catch
                outlines_py = [];
                has_outlines = false;
            end
        end

        % ---------- INIT ----------
        mask_cellpose       = cell(num_cells_mask, 1);
        props_cellpose      = struct('Area', cell(num_cells_mask, 1), ...
                                     'Centroid', cell(num_cells_mask, 1));
        outlines_x_cellpose = cell(num_cells_mask, 1);
        outlines_y_cellpose = cell(num_cells_mask, 1);

        % ---------- LOOP CELLULES ----------
        for i = 1:num_cells_mask

            label_i = labels(i);

            % masque
            mask_i = (masks_mat == label_i);
            mask_cellpose{i} = logical(mask_i);

            % propriétés (plus grande composante)
            props = regionprops(mask_i, 'Area', 'Centroid');

            if ~isempty(props)
                [~, imax] = max([props.Area]);
                props_cellpose(i).Area     = props(imax).Area;
                props_cellpose(i).Centroid = props(imax).Centroid;
            else
                props_cellpose(i).Area     = 0;
                props_cellpose(i).Centroid = [NaN NaN];
            end

            % ---------- contour ----------
            xord = [];
            yord = [];

            if has_outlines
                try
                    [xord, yord] = extract_cellpose_outline(outlines_py, i);
                catch
                    xord = [];
                    yord = [];
                end
            end

            % fallback fiable
            if isempty(xord) || isempty(yord)
                [xord, yord] = rebuild_outline_from_mask(mask_i);
            end

            outlines_x_cellpose{i} = xord;
            outlines_y_cellpose{i} = yord;
        end

    catch ME
        fprintf('Erreur load_or_process_cellpose_data: %s\n', ME.message);
    end
end

function [xord, yord] = extract_cellpose_outline(outlines_py, idx)

    xord = [];
    yord = [];

    try
        outline_i = outlines_py{idx-1}; % python index
    catch
        return;
    end

    if isempty(outline_i)
        return;
    end

    % conversion
    contour = [];
    try
        contour = double(py.numpy.array(outline_i));
    catch
        return;
    end

    if isempty(contour)
        return;
    end

    % Nx2 ou 2xN
    if size(contour,2) == 2
        xord = contour(:,1);
        yord = contour(:,2);
    elseif size(contour,1) == 2
        xord = contour(1,:)';
        yord = contour(2,:)';
    else
        return;
    end

    % nettoyage
    good = isfinite(xord) & isfinite(yord);
    xord = xord(good);
    yord = yord(good);

    if numel(xord) < 3
        xord = [];
        yord = [];
        return;
    end

    % fermer contour
    if xord(1) ~= xord(end) || yord(1) ~= yord(end)
        xord(end+1) = xord(1);
        yord(end+1) = yord(1);
    end
end

function [xord, yord] = rebuild_outline_from_mask(mask)

    xord = [];
    yord = [];

    if isempty(mask)
        return;
    end

    mask = logical(mask);

    if ~any(mask(:))
        return;
    end

    mask = imclose(mask, strel('disk',1));
    mask = imfill(mask,'holes');

    B = bwboundaries(mask, 'noholes');
    if isempty(B)
        return;
    end

    [~, imax] = max(cellfun(@(b) size(b,1), B));
    b = B{imax};

    yord = b(:,1);
    xord = b(:,2);

    if xord(1) ~= xord(end) || yord(1) ~= yord(end)
        xord(end+1) = xord(1);
        yord(end+1) = yord(1);
    end
end