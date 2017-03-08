%% InternalModesWKBSpectral
% 
% This class solves the vertical eigenvalue problem on a WKB stretched
% density coordinate grid using Chebyshev polynomials.
%
% Internally, sLobatto is the stretched density coordinate on a Chebyshev
% extrema/Lobatto grid. This is the grid upon which the eigenvalue problem
% is solved, and therefore the class uses the superclass properties denoted
% with 'x' instead of 's' when setting up the eigenvalue problem.
classdef InternalModesWKBSpectral < InternalModesSpectral
    properties %(Access = private)    
        xiLobatto            % stretched density coordinate, on Chebyshev extrema/Lobatto grid
        z_xiLobatto          % The value of z, at the sLobatto points
        xiOut                % desired locations of the output in s-coordinate (deduced from z_out)
        
        N_zCheb
        Nz_xLobatto     	% (d/dz)N on the xiLobatto grid   
    end
    

    
    methods
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Initialization
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = InternalModesWKBSpectral(rho, z_in, z_out, latitude, varargin)
            self@InternalModesSpectral(rho,z_in,z_out,latitude, varargin{:});
        end
                
        % Superclass calls this method upon initialization when it
        % determines that the input is given in gridded form.
        %
        % The superclass will initialize zLobatto and rho_lobatto;
        % this class must initialize the sLobatto, z_sLobatto and
        % sOut.
        function self = InitializeWithGrid(self, rho, z_in)
            % Superclass initializes zLobatto and rho_lobatto
            InitializeWithGrid@InternalModesSpectral(self, rho, z_in);
            
            % The user requested that the eigenvalue problem be solved on a
            % grid of particular length
            if self.nEVP > 0
                if self.nModes > self.nEVP
                    self.nEVP = self.nModes;
                end    
            else
                self.nEVP = 513; % 2^n + 1 for a fast Chebyshev transform
            end
            
            if isempty(self.nModes) || self.nModes < 1
                self.nModes = floor(self.nEVP/2);
            end
            
            % Create the stretched grid \xi
            N_zLobatto = sqrt(ifct(self.N2_zCheb));
            self.N_zCheb = fct(N_zLobatto);
            xi_zLobatto = cumtrapz(self.zLobatto,N_zLobatto);
            Lxi = max(xi_zLobatto)-min(xi_zLobatto);
            n = self.nEVP;
            self.xiLobatto = (Lxi/2)*( cos(((0:n-1)')*pi/(n-1)) + 1) + min(xi_zLobatto);
            
            % Now we need z on the \xi grid
            self.z_xiLobatto = interp1(xi_zLobatto, self.zLobatto, self.xiLobatto, 'spline');
            
            % and z_out on the \xi grid
            self.xiOut = interp1(self.zLobatto, xi_zLobatto, self.z, 'spline');
        end
        
        % Superclass calls this method upon initialization when it
        % determines that the input is given in functional form.
        %
        % The superclass will initialize zLobatto and rho_lobatto;
        % this class must initialize the sLobatto, z_sLobatto and
        % sOut.
        function self = InitializeWithFunction(self, rho, zMin, zMax, zOut)
            % Superclass initializes zLobatto and rho_lobatto
            InitializeWithFunction@InternalModesSpectral(self, rho, zMin, zMax, zOut);
            
            % The user requested that the eigenvalue problem be solved on a
            % grid of particular length
            if self.nEVP > 0
                if self.nModes > self.nEVP
                    self.nEVP = self.nModes;
                end    
            else
                self.nEVP = 513; % 2^n + 1 for a fast Chebyshev transform
            end
            
            if isempty(self.nModes) || self.nModes < 1
                self.nModes = floor(self.nEVP/2);
            end
            
            % Create the stretched grid \xi
            N_zLobatto = sqrt(ifct(self.N2_zCheb));
            self.N_zCheb = fct(N_zLobatto);
            xi_zLobatto = cumtrapz(self.zLobatto,N_zLobatto);
            Lxi = max(xi_zLobatto)-min(xi_zLobatto);
            n = self.nEVP;
            self.xiLobatto = (Lxi/2)*( cos(((0:n-1)')*pi/(n-1)) + 1) + min(xi_zLobatto);
            
            % Now we need z on the \xi grid
            self.z_xiLobatto = interp1(xi_zLobatto, self.zLobatto, self.xiLobatto, 'spline');
            
            % and z_out on the \xi grid
            self.xiOut = interp1(self.zLobatto, xi_zLobatto, self.z, 'spline');
        end
        
        function self = SetupEigenvalueProblem(self)
            % We will use the stretched grid to solve the eigenvalue
            % problem.
            self.xLobatto = self.xiLobatto;
            
            % The eigenvalue problem will be solved using N2 and N2z, so
            % now we need transformations to project them onto the
            % stretched grid
            T_zCheb_xiLobatto = ChebyshevTransformForGrid(self.zLobatto, self.z_xiLobatto);
            self.N2_xLobatto = T_zCheb_xiLobatto(self.N2_zCheb);
            self.Nz_xLobatto = T_zCheb_xiLobatto(self.Diff1_zCheb * self.N_zCheb);
            
            Lxi = max(self.xiLobatto) - min(self.xiLobatto);
            self.Diff1_xCheb = (2/Lxi)*ChebyshevDifferentiationMatrix( length(self.xiLobatto) );
            [self.T_xLobatto,self.Tx_xLobatto,self.Txx_xLobatto] = ChebyshevPolynomialsOnGrid( self.xiLobatto, length(self.xiLobatto) );
            
            [self.T_xCheb_zOut, self.doesOutputGridSpanDomain] = ChebyshevTransformForGrid(self.xiLobatto, self.xiOut);
            
            % We use that \int_{-1}^1 T_n(x) dx = \frac{(-1)^n + 1}{1-n^2}
            % for all n, except n=1, where the integral is zero.
            np = (0:(self.nEVP-1))';
            self.Int_xCheb = -(1+(-1).^np)./(np.*np-1);
            self.Int_xCheb(2) = 0;
            self.Int_xCheb = Lxi/2*self.Int_xCheb;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Computation of the modes
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [F,G,h] = ModesAtWavenumber(self, k )
            T = self.T_xLobatto;
            Tz = self.Tx_xLobatto;
            Tzz = self.Txx_xLobatto;
            n = self.nEVP;
            
%             a = diag(self.N2_xLobatto .* self.N2_xLobatto)*Tz;
%             b = diag(self.N2z_xLobatto)*Tz;
%             c = k*k*T;
%             d = diag( (self.f0*self.f0 - self.N2_xLobatto)/self.g )*T;
%             climits = [-10 -3];
%             figure
%             subplot(2,2,1)
%             pcolor(log10(abs(a))), shading flat, caxis(climits)
%             subplot(2,2,2)
%             pcolor(log10(abs(b))), shading flat, caxis(climits)
%             subplot(2,2,3)
%             pcolor(log10(abs(c))), shading flat, caxis(climits)
%             subplot(2,2,4)
%             pcolor(log10(abs(d))), shading flat, caxis(climits)
%             
            A = diag(self.N2_xLobatto)*Tzz + diag(self.Nz_xLobatto)*Tz - k*k*T;
            B = diag( (self.f0*self.f0 - self.N2_xLobatto)/self.g )*T;
            
            % Lower boundary is rigid, G=0
            A(n,:) = T(n,:);
            B(n,:) = 0;
            
            % G=0 or G_z = \frac{1}{h_j} G at the surface, depending on the BC
            if strcmp(self.upperBoundary, 'free_surface')
                % G_z = \frac{1}{h_j} G at the surface
                A(1,:) = Tz(1,:);
                B(1,:) = T(1,:);
            elseif strcmp(self.upperBoundary, 'rigid_lid')
                A(1,:) = T(1,:);
                B(1,:) = 0;
            end
            
            hFromLambda = @(lambda) 1.0 ./ lambda;
            GFromGCheb = @(G_cheb,h) self.T_xCheb_zOut(G_cheb);
            FFromGCheb = @(G_cheb,h) h * sqrt(self.N2) .* self.T_xCheb_zOut(self.Diff1_xCheb*G_cheb);
            [F,G,h] = self.ModesFromGEP(A,B,hFromLambda,GFromGCheb,FFromGCheb);
        end
        
        function [F,G,h] = ModesAtFrequency(self, omega )
            error('This function is not yet implemented!');
        end
        
        % Take matrices A and B from the generalized eigenvalue problem
        % (GEP) and returns F,G,h. The h_func parameter is a function that
        % returns the eigendepth, h, given eigenvalue lambda from the GEP.
        function [F,G,h] = ModesFromGEP(self,A,B,hFromLambda,GFromGCheb,FFromGCheb)
            [V,D] = eig( A, B );
            
            [lambda, permutation] = sort(abs(diag(D)),1,'ascend');
            G_cheb=V(:,permutation);
            h = hFromLambda(lambda.');
            
            F = zeros(length(self.z),self.nModes);
            G = zeros(length(self.z),self.nModes);
            h = h(1:self.nModes);
            
            % This still need to be optimized to *not* do the transforms
            % twice, when the EVP grid is the same as the output grid.
            [~,maxIndexZ] = max(self.zLobatto);
            for j=1:self.nModes
                Fj = h(j)*ifct(self.Diff1_xCheb*G_cheb(:,j));
                Gj = ifct(G_cheb(:,j));
                if strcmp(self.normalization, 'max_u')
                    A = max( abs( Fj ));
                elseif strcmp(self.normalization, 'max_w')
                    A = max( abs( Gj ) );
                elseif strcmp(self.normalization, 'const_G_norm')
                    J = (1/self.g) * (self.N2_xLobatto - self.f0*self.f0) .* ( self.N2_xLobatto.^(-0.5) ) .* Gj .^ 2;
                    A = sqrt(abs(sum(self.Int_xCheb .*fct(J))));
                elseif strcmp(self.normalization, 'const_F_norm')
                    J = (1/self.Lz) * (Fj.^ 2) .* ( self.N2_xLobatto.^(-0.5) );
                    A = sqrt(abs(sum(self.Int_xCheb .*fct(J))));
                end
                if Fj(maxIndexZ) < 0
                    A = -A;
                end
                
                G(:,j) = GFromGCheb(G_cheb(:,j),h(j))/A;
                F(:,j) = FFromGCheb(G_cheb(:,j),h(j))/A;
            end
        end

        
    end
    
end
