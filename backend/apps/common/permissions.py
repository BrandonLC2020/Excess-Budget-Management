from django.core.exceptions import ObjectDoesNotExist, ValidationError
from .exceptions import NotFoundError

def get_owned_or_404(model, obj_id, user):
    """Fetch a model instance owned by `user` or raise NotFoundError.
    The User model itself uses id matching; other models match user_id."""
    try:
        if model.__name__ == "User":
            obj = model.objects.get(id=obj_id)
            if obj.id != user.id:
                raise NotFoundError(f"{model.__name__} not found.")
            return obj
        return model.objects.get(id=obj_id, user_id=user.id)
    except (ObjectDoesNotExist, ValidationError) as e:
        raise NotFoundError(f"{model.__name__} not found.") from e
