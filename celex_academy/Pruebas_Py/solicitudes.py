
from supabase import create_client

import os

# CONEXION A SUPABASE
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]

admin = create_client(url, clave)

# DATOS DE LA SOLICITUD
IDIOMA_ID = 3
NIVEL_ID = 32
PERIODO_ID = 5

TIPO_TRAMITE = "Continuar al siguiente nivel"

# VERIFICAR IDIOMA Y NIVEL
print("\n========== VERIFICACION ==========")

try:
    verificacion = (
        admin.table("niveles")
        .select("id, nombre, idioma_id, activo")
        .eq("id", NIVEL_ID)
        .eq("idioma_id", IDIOMA_ID)
        .eq("activo", True)
        .execute()
    )

    if not verificacion.data:
        print("ERROR: El nivel no pertenece al idioma o no está activo.")
        raise SystemExit

    print("Nivel encontrado:")
    print(verificacion.data)

    idioma = (
        admin.table("idiomas")
        .select("id, nombre, activo")
        .eq("id", IDIOMA_ID)
        .eq("activo", True)
        .execute()
    )

    if not idioma.data:
        print("ERROR: El idioma no existe o no está activo.")
        raise SystemExit

    print("Idioma encontrado:")
    print(idioma.data)

except Exception as error:
    print("Error al verificar los datos:", error)
    raise SystemExit

# VERIFICAR PERIODO
periodo = (
    admin.table("periodos")
    .select("id, nombre, estado")
    .eq("id", PERIODO_ID)
    .execute()
)

if not periodo.data:
    print("ERROR: El periodo no existe.")
    raise SystemExit

print("\nPeriodo:", periodo.data[0])

if periodo.data[0]["estado"] != "Inscripciones":
    print("ERROR: El periodo no está en Inscripciones.")
    raise SystemExit

# CONFIRMAR DATOS
print("\n========== SOLICITUDES A REGISTRAR ==========")
print("Idioma:", idioma.data[0]["nombre"])
print("Nivel:", verificacion.data[0]["nombre"])
print("Periodo:", periodo.data[0]["nombre"])
print("Tipo de trámite:", TIPO_TRAMITE)
print("Alumnos: 3 al 21")

confirmar = input("\n¿Continuar? (S/N): ").strip().upper()

if confirmar != "S":
    print("Proceso cancelado.")
    raise SystemExit

# REGISTRAR SOLICITUDES
registradas = 0
existentes = 0
errores = 0

for numero in range(3, 22):

    correo = f"alumno{numero}@celex.test"
    contrasena = f"alumno{numero}"

    print(f"\nProcesando {correo}...")

    alumno = None

    try:
        # Cliente independiente para cada alumno.
        alumno = create_client(url, clave)

        # Iniciar sesión con la cuenta existente.
        respuesta = alumno.auth.sign_in_with_password({
            "email": correo,
            "password": contrasena
        })

        estudiante_id = respuesta.user.id

        # Verificar si ya existe la misma solicitud.
        consulta = (
            alumno.table("solicitudes")
            .select("id, estado")
            .eq("estudiante_id", estudiante_id)
            .eq("idioma_id", IDIOMA_ID)
            .eq("nivel_id", NIVEL_ID)
            .eq("periodo_id", PERIODO_ID)
            .eq("tipo_tramite", TIPO_TRAMITE)
            .execute()
        )

        if consulta.data:
            print(
                f"Ya existe la solicitud "
                f"ID: {consulta.data[0]['id']}"
            )
            existentes += 1
            continue

        # Registrar solicitud.
        # La base de datos asigna el estado predeterminado
        # y ejecuta sus triggers de validación.
        resultado = (
            alumno.table("solicitudes")
            .insert({
                "estudiante_id": estudiante_id,
                "idioma_id": IDIOMA_ID,
                "periodo_id": PERIODO_ID,
                "tipo_tramite": TIPO_TRAMITE,
                "nivel_id": NIVEL_ID
            })
            .execute()
        )

        if resultado.data:
            print(
                f"Solicitud registrada correctamente. "
                f"ID: {resultado.data[0]['id']}"
            )
            registradas += 1

    except Exception as error:
        print(f"ERROR con {correo}: {error}")
        errores += 1

    finally:
        # Cerrar sesión del alumno al terminar.
        if alumno is not None:
            try:
                alumno.auth.sign_out()
            except Exception:
                pass

# RESUMEN FINAL
print("\n========================================")
print("          RESUMEN DEL PROCESO")
print("========================================")
print(f"Solicitudes nuevas: {registradas}")
print(f"Solicitudes existentes: {existentes}")
print(f"Errores: {errores}")
print("========================================")
print("Proceso terminado.")
