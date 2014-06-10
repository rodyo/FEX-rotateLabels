% set dates in stead of JD as a plot's x-axis
function h = setXlabelsFromJD(varargin)
    
    %% initialize
    
    % set default rotation of text
    % positive: rotate counterclockwise, upper-right is on tick
    % negative: rotate clockwise, upper-left is on tick
    rotation  = +15;
    
    
    
    % default error check
    error(nargchk(2,inf,nargin));
    
    if ~ishandle(h)
        error('setXlabelsFromJD:need_plot_handle',...
            ['Method setXlabelsFromJD() takes two arguments: the plot ',...
            'handle (h) and the timerange in the plot (t).']);
    end
    
    % see if the fist argument is a plot handle. If so, extract it,
    % otherwise, operate on the current figure.
    h = gcf;
    if ~isempty(varargin{1})
        if ishandle(varargin{1})
            h = varargin{1};
            varargin = varargin(2:end);            
        end
        % also do an error check here
        if mod(numel(varargin),2) ~= 0
            error('setXlabelsFromJD:param_values_expected',...
                ['Additional options of setXlabelsFromJD() must be given in the ',...
                'form of parameter-value pairs.']);
        end
    end
    
    % split pv-pairs for clarity
    parameters = varargin(1:2:end);
    values     = varargin(2:2:end);
    
    % and loop through them
    for pv = 1:numel(parameters)
        
        % rename for clarity
        parameter = parameters{pv};
        value     = values{pv};
        
        % main switch
        switch lower(parameter)
            
            case 'rotation'
                if ~isscalar(value)
                    error('setXlabelsFromJD:rotation_mustbe_scalar',...
                        'Option ''rotation'' expects a scalar value.');
                end
                rotation = value;
                
            case 'convert'
                
            case ''
                
            otherwise
                warning('setXlabelsFromJD:unknown_option',...
                    ['Unkown option: ''%s''. Type ''help setXlabelsFromJD'' ',...
                    'for a list of valid options. Ignoring...'], parameter);
        end
    end % parse varargin loop
    
    % call the nested function on first call
    setLabels(true);
    
    % NOTE: the other nested functions are used as callbacks in the figure's
    % 'zoom', 'pan', 'resize' and 'windowbuttonmotionfcn' functions. 
     
    %% set the labels
    
    function setLabels(resizeAxs)
        
        % make vector containing JD (min. length 2)
        xLabelList = get(gca, 'xtick');
        % chop-off first entry: looks bettwe
        xLabelList = xLabelList(2:end);
        [y,M,d,H,m,s] = JD2date(xLabelList(:));
        % auto-adjust format if difference between first two
        % entries is less than a day
        if xLabelList(2)-xLabelList(1) <= 1
            format = 'dd/mmm/yyyy HH:MM';
        else
            format = 'dd/mmm/yyyy';
        end
        dates = datestr([y,M,d,H,m,s], format);
        
        
        % make (h) the current figure
        figure(h)
        % reduce axis size?
        if resizeAxs
            % reduce axis size so that Xlabels are still possible
            pos = get(gca,'Position');
            set(gca,'Position',[pos(1), pos(2)+0.05, pos(3) pos(4)*0.9]);
        end
        % remove current labels
        set(gca, 'XTickLabel', '')
        % some values to get initial coordinates for the labels
        % NOTE: this way we don't have to mess with the figure's units
        yrange = get(gca, 'Ylim');
        ymin   = min(yrange);
        ymax   = max(yrange);
        ytext  = ymin-(ymax-ymin)/15;
        xtext  = xLabelList;
        % set first new label to get extent
        t = text(xtext(1), ytext, dates(1,:), ...
            'rotation', rotation,...
            'VerticalAlignment'  ,'top', ...
            'HorizontalAlignment','center');
        ext = get(t, 'extent'); delete(t);
        % adjust xtext/ytext to fit
        if sign(rotation) < 0
            xtext = xtext + ext(3)/2;
            ytext = ymin - ext(4)/2 + (ymax-ymin)/25;
        else
            xtext = xtext - ext(3)/2;
            ytext = ymin - ext(4)/2 + (ymax-ymin)/25;
        end
        % set all new labels
        t = zeros(size(xLabelList));
        for jj = 1:length(xLabelList)
            t(jj) = text(xtext(jj), ytext, dates(jj,:), ...
                'rotation', rotation,...
                'VerticalAlignment'  ,'top', ...
                'HorizontalAlignment','center');
        end
        % save the current axes and text handles in figure's userdata field
        % NOTE: we have to append it to be compatible with subplot()
        data = get(h, 'userdata');
        if isempty(data) || ~any([data(:).axes]==gca)
            data(end+1).handles = t;
            data(end).axes = gca;
        else
            index = ([data(:).axes]==gca);
            data(index).handles = t;
        end
        set(gcf, 'userdata', data);
        
        % relocate the X-label (if any)
        if ~isempty(get(gca, 'xlabel'))
            ext  = get(t(1), 'extent');
            xlim = get(gca, 'xlim');
            newposition = [(xlim(1)+xlim(end))/2, ext(2), 0];
            set(get(gca, 'Xlabel'), ...
                'position', newposition,...
                'VerticalAlignment'  ,'top', ...
                'HorizontalAlignment','center');
        end
        % relocate the title (if any)
        if ~isempty(get(gca, 'title'))
            ylim = get(gca, 'ylim');
            xlim = get(gca, 'xlim');
            newposition = [
                (xlim(1)+xlim(end))/2, ...
                ylim(2) + (ylim(2)-ylim(1))/10, 1];
            set(get(gca,'title'), ...
                'position', newposition,...
                'VerticalAlignment'  ,'bottom', ...
                'HorizontalAlignment','center');
        end
        
        % assign new callback function to figure resize
        set(gcf,...
            'resizefcn', @postOps1,...
            'windowbuttonmotionfcn', @postOps2);
        
        % assign new callback functions to zoom and pan functions
        h2 = zoom(h); set(h2, 'ActionPostCallback', @postOps2);
        h3 = pan(h);  set(h3, 'ActionPostCallback', @postOps2);
        
    end
    
    % actions to take after/during pan/resize (fix ALL axes)
    function postOps1(varargin)
        data = get(h,'userdata');
        for ii = 1:numel(data)
            delete(data(ii).handles);
            set(h, 'currentaxes', data(ii).axes);
            setLabels(false);
        end
    end
    
    % actions to take after zoom
    function postOps2(varargin)
        % return if no button's been pressed
        if ~any([
                strcmp(get(findall(gcf,'tag','Exploration.ZoomIn'),'state'),'on')
                strcmp(get(findall(gcf,'tag','Exploration.ZoomOut'),'state'),'on')
                strcmp(get(findall(gcf,'tag','Exploration.Pan'),'state'),'on')])
            return
        end
        % otherwise, redraw labels on current axes
        data = get(h,'userdata');
        index = ([data(:).axes] == gca);
        if any(index)
            % sometimes, when returning a zoom to default view with
            % double-click, this function gets called twice and the
            % handles are no longer valid:
            if all(ishandle(data(index).handles))
                delete(data(index).handles);
                setLabels(false);
            end
        end
    end
    
end % set rotated x-labels
