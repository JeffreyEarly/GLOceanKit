classdef InternalModes < handle
    properties (Access = public)
        latitude
        f0
        normalization = 'const_G_norm'
        upper_boundary = 'rigid_lid'
        method = 'scaled_spectral'
        rho
        z
        N2
    end
    
    properties (Access = protected)
    end
    
    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Initialization
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = InternalModes(rho, z, latitude, method)
            % Is density specified as a function handle or as a grid of
            % values?
            if isa(rho,'function_handle') == true
                if numel(z) ~= 2
                    error('When using a function handle, z must be an array with two values: z=[z_min z_max];')
                end
            elseif isa(rho,'numeric') == true
                if numel(rho) ~= length(rho) || length(rho) ~= length(z)
                    error('rho must be 1 dimensional and z must have the same length');
                end
            else
                error('rho must be a function handle or an array.');
            end
            
            obj.latitude = latitude;
            
            if nargin == 4
                if  (~strcmp(method, 'scaled_spectral') && ~strcmp(method, 'finite_difference') && ~strcmp(method, 'spectral'))
                    error('Invalid method!')
                else
                    obj.method = method;
                end
            end
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Set the normalization and upper boundary condition
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function set.normalization(obj,norm)
            if  (~strcmp(norm, 'max_u') && ~strcmp(norm, 'max_w') && ~strcmp(norm, 'const_G_norm') && ~strcmp(norm, 'const_F_norm'))
                error('Invalid normalization!')
            else
                obj.normalization = norm;
            end
        end
        
        function set.upper_boundary(obj,upper_boundary)
            if  (~strcmp(upper_boundary, 'free_surface') && ~strcmp(upper_boundary, 'rigid_lid') )
                error('Invalid upper boundary condition!')
            else
                obj.upper_boundary = upper_boundary;
            end
        end
        
        function obj = ModesAtWavenumber(obj, k )
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Generical function to normalize
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [F,G] = NormalizeModes(obj,F,G,z)
            [~,maxIndexZ] = max(z);
            for j=1:length(G(1,:))
                if strcmp(obj.normalization, 'max_u')
                    A = max( abs(F(:,j)) );
                    G(:,j) = G(:,j) / A;
                    F(:,j) = F(:,j) / A;
                elseif strcmp(obj.normalization, 'max_w')
                    A = max( abs(G(:,j)) );
                    G(:,j) = G(:,j) / A;
                    F(:,j) = F(:,j) / A;
                elseif strcmp(obj.normalization, 'const_G_norm')
                    A = trapz( z, (1/g) * (obj.N2 - obj.f0*obj.f0) .* G(:,j) .^ 2);
                    G(:,j) = G(:,j) / sqrt(A);
                    F(:,j) = F(:,j) / sqrt(A);
                elseif strcmp(obj.normalizationnorm, 'const_F_norm')
                    A = abs(trapz( z_out, (1/abs(z(end)-z(1))) .* F(:,j) .^ 2));
                    G(:,j) = G(:,j) / sqrt(A);
                    F(:,j) = F(:,j) / sqrt(A);
                end
                
                if F(maxIndexZ,j)< 0
                    F(:,j) = -F(:,j);
                    G(:,j) = -G(:,j);
                end
            end
        end
    end
end

