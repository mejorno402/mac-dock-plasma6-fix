import os

def consolidar_codigo(directorio_origen, archivo_salida):
    ignorar_carpetas = ['.git', 'build', '.vscode', 'kcm/build']
    extensiones_validas = ['.cpp', '.h', '.json', '.txt', '.cmake', '.glsl', '.frag', '.vert', '.kcfgc', '.kcfg', '.qml']

    with open(archivo_salida, 'w', encoding='utf-8') as salida:
        for raiz, carpetas, archivos in os.walk(directorio_origen):
            carpetas[:] = [c for c in carpetas if c not in ignorar_carpetas]

            for archivo in archivos:
                es_valido = any(archivo.endswith(ext) for ext in extensiones_validas) or archivo == 'CMakeLists.txt'

                if es_valido:
                    ruta_completa = os.path.join(raiz, archivo)

                    salida.write(f"\n{'='*60}\n")
                    salida.write(f"--- ARCHIVO: {os.path.relpath(ruta_completa, directorio_origen)} ---\n")
                    salida.write(f"{'='*60}\n\n")

                    try:
                        with open(ruta_completa, 'r', encoding='utf-8') as f:
                            salida.write(f.read())
                    except Exception as e:
                        salida.write(f"// No se pudo leer el archivo: {e}\n")

if __name__ == '__main__':
    directorio_actual = os.getcwd()
    archivo_resultado = "panorama_completo.txt"
    consolidar_codigo(directorio_actual, archivo_resultado)
    print(f"¡Éxito! Todo el código se ha guardado en: {archivo_resultado}")
