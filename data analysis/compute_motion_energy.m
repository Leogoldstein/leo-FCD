function motion_energy = compute_motion_energy(movie_path, xrange, yrange)
    if nargin < 2, xrange = []; end
    if nargin < 3, yrange = []; end

    reader = bfGetReader(movie_path);
    cleanup = onCleanup(@() reader.close());

    sizeX = reader.getSizeX();
    sizeY = reader.getSizeY();
    sizeT = reader.getSizeT();   % time points (frames)
    sizeZ = reader.getSizeZ();
    sizeC = reader.getSizeC();

    % Beaucoup de stacks ImageJ sont stockés en T, mais parfois en Z.
    nFrames = max([sizeT, sizeZ]);  % fallback simple
    fprintf('Bio-Formats: X=%d Y=%d Z=%d C=%d T=%d -> using nFrames=%d\n', ...
        sizeX, sizeY, sizeZ, sizeC, sizeT, nFrames);

    if isempty(yrange), yrange = [1 sizeY]; end
    if isempty(xrange), xrange = [1 sizeX]; end

    motion_energy = zeros(1, nFrames-1, 'double');

    img_prev = double(readBFFrame(reader, 1, sizeZ, sizeC, sizeT, xrange, yrange));

    for i = 2:nFrames
        img = double(readBFFrame(reader, i, sizeZ, sizeC, sizeT, xrange, yrange));
        d = img - img_prev;
        motion_energy(i-1) = sum(d(:).^2);
        img_prev = img;

        if mod(i, 1000) == 0
            fprintf('Done %d/%d\n', i, nFrames);
        end
    end

    mmax = max(motion_energy);
    if mmax > 0, motion_energy = motion_energy / mmax; end
end

function img = readBFFrame(reader, i, sizeZ, sizeC, sizeT, xrange, yrange)
    % Essaye d'interpréter i comme T si T>1, sinon comme Z
    if sizeT > 1
        z = 1; c = 1; t = i;
    else
        z = i; c = 1; t = 1;
    end

    index = reader.getIndex(z-1, c-1, t-1) + 1; % 1-based for bfGetPlane
    plane = bfGetPlane(reader, index);

    img = plane(yrange(1):yrange(2), xrange(1):xrange(2));

    % Si jamais c’est multi-canal (rare ici), tu peux moyenner
    if ndims(img) > 2
        img = mean(double(img), 3);
    end
end