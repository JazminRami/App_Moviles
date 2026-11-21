
from supabase import create_client

# ==========================================
# CONEXION A SUPABASE
# ==========================================

url = input("URL de tu proyecto Supabase: ").strip()
clave = input("Pega tu service_role key: ").strip()

admin = create_client(url, clave)

# ==========================================
# CREAR ALUMNOS 2 AL 21
# ==========================================

for numero in range(2, 22):

    correo = f"alumno{numero}@celex.test"
    contrasena = f"alumno{numero}"
    nombre = f"Alumno {numero}"

    try:
        # Crear cuenta en Supabase Auth.
        # El trigger creará automáticamente su perfil.
        admin.auth.admin.create_user({
            "email": correo,
            "password": contrasena,
            "email_confirm": True,
            "user_metadata": {
                "nombre_completo": nombre,
                "categoria": "Público general"
            }
        })

        # Iniciar sesión como el alumno para respetar
        # la validación auth.uid() del trigger.
        alumno = create_client(url, clave)

        alumno.auth.sign_in_with_password({
            "email": correo,
            "password": contrasena
        })

        # Registrar solicitud de Inglés - Introductorio.
        alumno.table("solicitudes").insert({
            "estudiante_id": alumno.auth.get_user().user.id,
            "idioma_id": 1,
            "periodo_id": 2,
            "tipo_tramite": "Iniciar desde Introductorio",
            "nivel_id": 76,
            "estado": "Pendiente"
        }).execute()

        print(f"Alumno {numero}: creado y solicitud registrada.")

    except Exception as error:
        print(f"Error con {correo}: {error}")

print("\nProceso terminado.")
