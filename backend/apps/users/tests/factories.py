import factory
from factory.django import DjangoModelFactory
from apps.users.models import User, Profile


class UserFactory(DjangoModelFactory):
    class Meta:
        model = User

    email = factory.Sequence(lambda n: f"user{n}@example.com")
    password = factory.PostGenerationMethodCall("set_password", "testpassword123")
    is_active = True


class ProfileFactory(DjangoModelFactory):
    class Meta:
        model = Profile

    user = factory.SubFactory(UserFactory)
    full_name = factory.Faker("name")
