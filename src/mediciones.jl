function agregar_sencillo!(array_velocidad, array_flujo, array_densidad, i, t, T)

    v = ( array_densidad[i, t] != 0 ? array_flujo[i, t]/array_densidad[i, t] : 0 )
    array_velocidad[i, t] += v/T
end

function agregar_Frecuencias!(array2, v, i, t, j, x_seccion, T; tipo::Int64 = 2)

  if v.velocidad > 0
    if j-v.velocidad < x_seccion
      if v.tipo == tipo
        array2[i, t] += 1/T
      end
    end
  end
end

function agregar!(i, j, t, x_seccion, v, array, array1, array2, T)

    if v.velocidad > 0
        if j-v.velocidad < x_seccion
            array[i, t] += 1/T

            if v.tipo == 1
                array1[i, t] += 1/T
            end
            if v.tipo == 2
                array2[i, t] += 1/T
            end
        end
    end
end

function Medir_Frecuencias!(carretera, t, Secciones, T, flujo_local2, densidad_local2, flujo_local1, Diagrama_Transicion, j_in, p)

    for (i, Seccion) in enumerate(Secciones)
      for j = Seccion+4:-1:Seccion
            agregar_Frecuencias!(flujo_local2, carretera[j], i, t, j, Seccion, T)
            agregar_Frecuencias!(densidad_local2, carretera[j], i, t, j, Seccion, T*carretera[j].velocidad)
            agregar_Frecuencias!(flujo_local1, carretera[j], i, t, j, Seccion, T, tipo=1)

            if carretera[j].velocidad == 0 && (carretera[j].tipo == 1 || carretera[j].tipo == 2 )
                    Diagrama_Transicion[i, j_in, p] = 0
            end
      end
    end
end

#################################### Mediciones ######################################

function Medir!(C, t, Secciones, T, flujo_local, densidad_local ,
               velocidad_local_promedio, flujo_local1, densidad_local1 ,velocidad_local_promedio1,
               flujo_local2, densidad_local2 , velocidad_local_promedio2)


    #T = 1.  T es el periodo de tiempo por el cual se mide

    for (i, x_seccion) in enumerate(Secciones)

        # Medicion del flujo local
        for j = x_seccion+4:-1:x_seccion
            agregar!(i, j, t, x_seccion, C.carretera[j], flujo_local, flujo_local1, flujo_local2, T)
        end


        # Medicion de la densidad local
        for j = x_seccion+4:-1:x_seccion
            agregar!(i, j, t, x_seccion, C.carretera[j], densidad_local, densidad_local1, densidad_local2,
                    T*C.carretera[j].velocidad)
        end

        # Medicion de la velocidad promedio espacial

        agregar_sencillo!( velocidad_local_promedio, flujo_local, densidad_local, i, t, T )
        agregar_sencillo!( velocidad_local_promedio1, flujo_local1, densidad_local1, i, t, T )
        agregar_sencillo!( velocidad_local_promedio2, flujo_local2, densidad_local2, i, t, T )
    end
end

function ET!(X, T, carretera, t)

    for v in carretera
        if v.tipo == 1 || v.tipo == 2
            push!(X[v.num], v.posicion)
            push!(T[v.num], t)
        end
    end
end

function ET_tipo!(X, T, carretera, t, tipo::Int64)

    for v in carretera
        if v.tipo == tipo
            push!(X[v.num], v.posicion)
            push!(T[v.num], t)
        end
    end
end

function tiempos_salida!(Tiempos_salida::Array{Int64, 1}, Tiempos_salida1::Array{Int64, 1}, Tiempos_salida2::Array{Int64, 1},
                        T0::Array{Any,1}, T1::Array{Any,1}, T2::Array{Any,1},
                        X::Array{Any,1}, X1::Array{Any,1}, X2::Array{Any,1},
                        N::Int64 = 3862)

    for i in 1:length(X)
        if length(X[i]) != 0 && X[i][end] > N-6
            push!(Tiempos_salida, T0[i][end]-T0[i][1])
        end
        if length(X1[i]) != 0 && X1[i][end] > N-6
            push!(Tiempos_salida1, T1[i][end]-T1[i][1])
        end
        if length(X2[i]) != 0 && X2[i][end] > N-6
            push!(Tiempos_salida2, T2[i][end]-T2[i][1])
        end
    end
end

function tiempos_iniciales!(Tiempos_iniciales1::Array{Int64,1}, Tiempos_iniciales2::Array{Int64, 1},
                            T1::Array{Any, 1}, T2::Array{Any, 1}, X1::Array{Any, 1}, X2::Array{Any, 1}, N::Int64 = 3862)

  for i in 1:length(T1)
      if length(T1[i]) != 0 && X1[i][end] > N-6
          push!(Tiempos_iniciales1, T1[i][1])
      end
  end
  for i = 1:length(T2)
      if length(T2[i]) != 0 && X2[i][end] > N-6
          push!(Tiempos_iniciales2, T2[i][1])
      end
  end
end

function Tiempos_promedio(Tf::Int64, Tiempos_salida, Tiempos_iniciales)

    Ts_promedio = Any[]

    h = int64(ceil(Tf/900))

    for i = 1:h
        push!(Ts_promedio, Float64[])
    end

    for (l, lim) in enumerate(linspace(900, Tf, h))
        for i = 1:length(Tiempos_salida)
            if Tiempos_iniciales[i] <= lim
                push!(Ts_promedio[l], Tiempos_salida[i])
                Tiempos_iniciales[i] = Tf+1
            end
        end
    end

    Tiempos_salida_promedio = Float64[0.]
    Desviaciones_salida_promedio = Float64[0.]

    for i = 1:length(Ts_promedio)
        push!(Tiempos_salida_promedio, mean(Ts_promedio[i]))
        push!(Desviaciones_salida_promedio, std(Ts_promedio[i]))
    end

    Ts_promedio = 0
    return Tiempos_salida_promedio, Desviaciones_salida_promedio
end

function Medidas_DF!(Flujos_secciones_promedio::Array{Float64, 3}, D_Flujos_secciones_promedio::Array{Float64, 3}, densidad::Array{Float64, 3},
                     flujo::Array{Float64, 3}, secciones::Array{Int64, 1})

    for k = 1:size(Flujos_secciones_promedio)[3]
        for (i, s) in enumerate(secciones[1:end-1])
            for j =s:secciones[i+1]
                copia_d = copy([de for de in sub(densidad, j, :, k)][1:end-1])
                copia_f = copy([fl for fl in sub(flujo, j, :, k)][1:end-1])
                flujos_promedio, Desviaciones_flujos_promedio = Flujos_promedio(copia_f, copia_d)
                for l = 1:size(Flujos_secciones_promedio)[2]
                    Flujos_secciones_promedio[i, l, k] += flujos_promedio[l]/(secciones[i+1]-s+1)
                    D_Flujos_secciones_promedio[i, l, k] += Desviaciones_flujos_promedio[l]/(secciones[i+1]-s+1)
                end
                copia_d = copia_f = 0
            end
        end
    end
end

function Medidas_ET!(Medidas_secciones_promedio::Array{Float64, 3}, D_Medidas_secciones_promedio::Array{Float64, 3}, Medidas::Array{Float64, 3},
                     Tf::Int64, T::Int64, secciones::Array{Int64, 1})

    for k = 1:size(Medidas_secciones_promedio)[3]
        for (i, s) in enumerate(secciones[1:end-1])
            for j =s:secciones[i+1]
                 M_promedio_T, D_M_promedio_T = Flujos_promedio_T(Tf, T,
                                                    Float64[m for m in sub(Medidas, j, :, k)])
                 for l = 1:length(M_promedio_T)
                    Medidas_secciones_promedio[i, l, k] += M_promedio_T[l]/(secciones[i+1]-s+1)
                    D_Medidas_secciones_promedio[i, l, k] += D_M_promedio_T[l]/(secciones[i+1]-s+1)
                 end
                 M_promedio_T = D_M_promedio_T = 0
            end
        end
    end
end

function Flujos_promedio_T(Tf::Int64, T::Int64, Flujos::Array{Float64, 1})

    F_promedio_T = Float64[0.]
    D_F_promedio_T = Float64[0.]

    h = int(ceil(Tf/900))
    m = 900/T

    for i = 0:h-1
        push!(F_promedio_T, mean(Flujos[i*m+1:m*(i+1)]))
        push!(D_F_promedio_T, std(Flujos[i*m+1:m*(i+1)]))

    end

    return F_promedio_T, D_F_promedio_T
end

function Flujos_promedio(Flujos, Densidades)

    F_promedio = Any[]

    h = 20

    for i = 1:h
        push!(F_promedio, Float64[])
    end

    for (l, lim) in enumerate(linspace(0.05, 1, h))
        for i = 1:length(Flujos)
            if Densidades[i] <= lim
                push!(F_promedio[l], Flujos[i])
                Densidades[i] = 1.1
            end
        end
    end

    flujos_promedio = Float64[0.]
    Desviaciones_flujos_promedio = Float64[0.]

    for i = 1:length(F_promedio)
        push!(flujos_promedio, mean(F_promedio[i]))
        push!(Desviaciones_flujos_promedio, std(F_promedio[i]))
    end

    F_promedio = 0
    return flujos_promedio, Desviaciones_flujos_promedio
end
